from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from agents.evaluator.output import evaluation_run_dir, experiment_identity
from agents.evaluator.oracles import MissingOracle, case_provenance, digest
from agents.evaluator.troubleshooter.evidence import audit_evidence, load_observations
from agents.evaluator.troubleshooter.evidence_pack import CONDITIONS, load_pack, public_observations, select_observations
from agents.evaluator.troubleshooter.openhands_tools import register_diagnostic_tools
from agents.evaluator.troubleshooter.prompts import render_diagnosis_prompt, resolve_prompt_template
from agents.evaluator.troubleshooter.scoring import (
    DiagnosisPrediction,
    parse_diagnosis_response,
    prediction_document,
    score_diagnosis,
)
from agents.manager import (
    CaseDefinition,
    ContainerRuntime,
    DEFAULT_LLM_PROVIDER,
    OpenHandsConfig,
    TAXONOMY_PATH,
    capture_agent_exception,
    configure_agent_failure_context,
    load_repository_env,
    observe_stage,
    run_agent_entrypoint,
    run_openhands_agent,
    summarize_agent_usage,
)
from agents.manager.paths import instance_dir


REPO_ROOT = Path(__file__).resolve().parents[3]


def main(argv: list[str] | None = None) -> int:
    load_repository_env(REPO_ROOT)
    args = _parse_args(argv)
    configure_agent_failure_context(instance_id=args.instance_id)
    case = CaseDefinition.load(instance_dir(REPO_ROOT, args.instance_id))
    config = None if args.diagnosis_file else _openhands_config(args)
    experiment = experiment_identity(config, mode="offline" if config is None else "live")
    if args.evidence_mode != "none":
        experiment.update(protocol_version="rq3-v1", evidence_mode=args.evidence_mode)
        if args.evidence_mode == "replay":
            experiment["evidence_condition"] = args.evidence_condition
    run_dir = evaluation_run_dir(
        REPO_ROOT, "troubleshooter", args.instance_id, experiment, args.run_dir
    )
    run_dir.mkdir(parents=True, exist_ok=False)
    configure_agent_failure_context(instance_id=args.instance_id, run_dir=run_dir)
    result: dict[str, object] = {
        "instance_id": case.instance_id,
        "run_dir": str(run_dir),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "agent_role": "troubleshooter",
        "experiment": experiment,
        "evaluation_task": "root_cause_diagnosis",
        "success": False,
    }

    try:
        observations = []
        pack = None
        if args.evidence_mode == "replay":
            pack_path = Path(args.evidence_pack) if args.evidence_pack else Path(args.evidence_pack_dir) / f"{case.instance_id}.json"
            pack = load_pack(pack_path, case.instance_id, case)
            observations = select_observations(pack, args.evidence_condition)
            result["evidence_pack_sha256"] = digest(pack)
            result["evidence_pack"] = str(pack_path.resolve())
        if args.diagnosis_file:
            response = Path(args.diagnosis_file).read_text(encoding="utf-8")
            result["diagnosis_source"] = str(Path(args.diagnosis_file).resolve())
            if args.observations_file:
                observations = load_observations(Path(args.observations_file))
        else:
            prompt = render_diagnosis_prompt(
                case,
                TAXONOMY_PATH.read_text(encoding="utf-8"),
            )
            if args.evidence_mode != "none":
                prompt += "\n" + (REPO_ROOT / "prompts/misconfig_evidence.j2").read_text()
            if pack is not None:
                prompt += "\nThis is a frozen-evidence diagnosis. No environment tools are available.\n"
                prompt += json.dumps({"observations": public_observations(observations)}, ensure_ascii=True)
                result["selected_observation_ids"] = [item["id"] for item in observations]
            result["provenance"] = case_provenance(case, prompt)
            prompt_path = run_dir / "task_prompt.md"
            prompt_path.write_text(prompt, encoding="utf-8")
            result["prompt_template"] = str(resolve_prompt_template(case))
            result["task_prompt"] = str(prompt_path)
            assert config is not None
            if pack is not None:
                response = _run_evidence_replay(prompt, run_dir, config)
            else:
                response = _run_diagnosis_agent(prompt, case, run_dir, config,
                                                collect_evidence=args.evidence_mode == "collect")
                if args.evidence_mode == "collect":
                    path = run_dir / "evidence_observations.jsonl"
                    observations = load_observations(path) if path.exists() else []
            result["agent_response"] = response

        try:
            prediction = parse_diagnosis_response(response)
        except ValueError as exc:
            result["diagnosis_valid"] = False
            result["diagnosis_error"] = str(exc)
            if args.evidence_mode != "none":
                result["evidence"] = {"status": "invalid_diagnosis", "core_claim_support_rate": None}
                (run_dir / "evidence_result.json").write_text(json.dumps(result["evidence"]) + "\n")
            scored = score_diagnosis(
                case,
                DiagnosisPrediction(type_id=None, subtype_id=None, locations=()),
            )
            scored["diagnosis_valid"] = False
            result["result"] = scored
            result["success"] = True
            return 0

        diagnosis_path = run_dir / "diagnosis.json"
        diagnosis_path.write_text(
            json.dumps(prediction_document(prediction), indent=2, ensure_ascii=True)
            + "\n",
            encoding="utf-8",
        )
        scored = score_diagnosis(case, prediction)
        if args.evidence_mode != "none":
            review = json.loads(Path(args.evidence_review).read_text()) if args.evidence_review else None
            try:
                evidence = audit_evidence(case, prediction_document(prediction), observations, review)
                if pack is not None:
                    evidence["acquisition_status"] = "not_applicable_replay"
                    evidence["sufficient_evidence_acquired"] = None
                    evidence.pop("first_sufficient_evidence", None)
                result["evidence"] = evidence
            except ValueError as exc:
                result["evidence_error"] = str(exc)
                result["evidence"] = {"status": "invalid", "core_claim_support_rate": None}
            (run_dir / "evidence_result.json").write_text(json.dumps(result["evidence"], indent=2) + "\n")
            if "review_template" in result["evidence"]:
                (run_dir / "evidence_review.template.json").write_text(
                    json.dumps(result["evidence"]["review_template"], indent=2) + "\n")
        scored["diagnosis_valid"] = True
        result["diagnosis_valid"] = True
        result["diagnosis"] = str(diagnosis_path)
        result["result"] = scored
        result["success"] = True
        return 0
    except MissingOracle as exc:
        result["status"] = "skipped_missing_oracle"
        result["error"] = str(exc)
        return 2
    except Exception as exc:  # noqa: BLE001
        result["error"] = f"{type(exc).__name__}: {exc}"
        capture_agent_exception(exc)
        return 1
    finally:
        result["agent_usage"] = summarize_agent_usage(run_dir)
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
        (run_dir / "diagnosis_result.json").write_text(
            json.dumps(result, indent=2, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(result, indent=2, ensure_ascii=True))


@observe_stage(
    "troubleshooter",
    "diagnose_root_cause",
    ignore_inputs=["task_prompt", "case", "run_dir", "config"],
    log_context=lambda task_prompt, case, run_dir, config, **kwargs: (
        f"{case.instance_id}, model {config.model}"
    ),
)
def _run_diagnosis_agent(
    task_prompt: str,
    case: CaseDefinition,
    run_dir: Path,
    config: OpenHandsConfig,
    *,
    collect_evidence: bool = False,
) -> str:
    with ContainerRuntime(case) as runtime:
        tools = register_diagnostic_tools(runtime, run_dir / "evidence_observations.jsonl" if collect_evidence else None)
        return run_openhands_agent(task_prompt, tools, run_dir, config)


def _openhands_config(args: argparse.Namespace) -> OpenHandsConfig:
    return OpenHandsConfig.from_environment(
        model=args.model,
        provider=args.llm_provider,
        api_key=args.api_key,
        base_url=args.base_url,
        subscription_login=args.subscription_login,
        max_iterations=args.max_iterations,
        max_runtime_seconds=args.agent_timeout,
    )


@observe_stage("troubleshooter", "replay_evidence", ignore_inputs=["prompt", "run_dir", "config"])
def _run_evidence_replay(prompt: str, run_dir: Path, config: OpenHandsConfig) -> str:
    return run_openhands_agent(prompt, [], run_dir, config)


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run or score a structured root-cause diagnosis for a MisconfigBench case."
        )
    )
    parser.add_argument("instance_id")
    parser.add_argument(
        "--diagnosis-file",
        help="Score an existing JSON diagnosis response without invoking an LLM.",
    )
    parser.add_argument("--model", default=None)
    parser.add_argument(
        "--llm-provider",
        choices=["openai_subscription", "openlux"],
        default=os.getenv("MISCONFIGBENCH_LLM_PROVIDER", DEFAULT_LLM_PROVIDER),
    )
    parser.add_argument("--api-key")
    parser.add_argument("--base-url")
    parser.add_argument("--subscription-login", action="store_true")
    parser.add_argument("--max-iterations", type=int, default=30)
    parser.add_argument(
        "--agent-timeout",
        type=int,
        default=int(os.getenv("MISCONFIGBENCH_AGENT_TIMEOUT_SECONDS", "900")),
    )
    parser.add_argument("--run-dir")
    parser.add_argument("--evidence-mode", choices=["none", "collect", "replay"], default="none")
    parser.add_argument("--evidence-condition", choices=CONDITIONS, default="full")
    parser.add_argument("--evidence-pack")
    parser.add_argument("--evidence-pack-dir", help="Batch replay: directory of <ID>.json packs.")
    parser.add_argument("--observations-file", help="Saved ledger for offline evidence audit.")
    parser.add_argument("--evidence-review", help="Human support review bound to this prediction and ledger.")
    args = parser.parse_args(argv)
    if args.evidence_mode == "replay" and not (args.evidence_pack or args.evidence_pack_dir):
        parser.error("replay requires --evidence-pack or --evidence-pack-dir")
    if args.evidence_mode != "replay" and (args.evidence_pack or args.evidence_pack_dir or args.evidence_condition != "full"):
        parser.error("evidence pack/condition require replay mode")
    if args.observations_file and (not args.diagnosis_file or args.evidence_mode != "collect"):
        parser.error("--observations-file requires offline diagnosis and evidence-mode collect")
    if args.evidence_review and not args.diagnosis_file:
        parser.error("--evidence-review is only used for offline scoring")
    if args.diagnosis_file and args.evidence_mode == "collect" and not args.observations_file:
        parser.error("offline evidence audit requires --observations-file")
    return args


if __name__ == "__main__":
    sys.exit(run_agent_entrypoint("troubleshooter", main))
