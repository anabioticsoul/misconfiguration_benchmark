from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from agents.evaluator.fixer.prompts import render_case_prompt, resolve_prompt_template
from agents.evaluator.output import evaluation_run_dir, experiment_identity
from agents.evaluator.oracles import MissingOracle, case_provenance
from agents.manager import (
    CaseDefinition,
    ContainerRuntime,
    DEFAULT_LLM_PROVIDER,
    OpenHandsConfig,
    build_prediction_patch,
    capture_agent_exception,
    configure_agent_failure_context,
    evaluate_prediction,
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
    config = _openhands_config(args) if args.agent != "manual" else None
    experiment = experiment_identity(config, mode="manual" if config is None else "live")
    experiment.update(protocol_version="rq2-v1", repair_context=args.repair_context)
    run_dir = evaluation_run_dir(REPO_ROOT, "fixer", args.instance_id, experiment, args.run_dir)
    run_dir.mkdir(parents=True, exist_ok=False)
    configure_agent_failure_context(
        instance_id=args.instance_id,
        run_dir=run_dir,
    )

    result = {
        "instance_id": case.instance_id,
        "run_dir": str(run_dir),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "agent": args.agent,
        "agent_role": "fixer",
        "experiment": experiment,
        "evaluation_task": "configuration_repair",
        "prompt_template": str(resolve_prompt_template(case)),
        "success": False,
    }
    try:
        task_prompt = render_case_prompt(case, args.repair_context)
        result["provenance"] = case_provenance(case, task_prompt)
        task_prompt_path = run_dir / "task_prompt.md"
        task_prompt_path.write_text(task_prompt, encoding="utf-8")
        result["task_prompt"] = str(task_prompt_path)

        with ContainerRuntime(case, keep_container=args.keep_container) as runtime:
            result["container_name"] = runtime.container_name
            if args.agent == "manual":
                _run_manual_shell(runtime)
            else:
                assert config is not None
                result["agent_response"] = _run_openhands_agent(
                    task_prompt,
                    runtime,
                    run_dir,
                    config,
                )

            patch = _export_prediction_patch(case, runtime, run_dir)
            patch_path = run_dir / "prediction.diff"
            patch_path.write_text(patch, encoding="utf-8")
            result["prediction_patch"] = str(patch_path)

        result["evaluation"] = _evaluate_fixer_patch(
            case, patch_path, has_patch=bool(patch)
        )
        result["success"] = result["evaluation"]["exit_code"] == 0
        return 0 if result["success"] else 1
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
        (run_dir / "result.json").write_text(
            json.dumps(result, indent=2, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(result, indent=2, ensure_ascii=True))


@observe_stage(
    "fixer",
    "run_agent",
    ignore_inputs=["task_prompt", "runtime", "run_dir", "config"],
    log_context=lambda task_prompt, runtime, run_dir, config: (
        f"{runtime.case.instance_id} in {runtime.container_name} "
        f"with model {config.model}"
    ),
)
def _run_openhands_agent(
    task_prompt: str,
    runtime: ContainerRuntime,
    run_dir: Path,
    config: OpenHandsConfig,
) -> str:
    os.environ.setdefault("OPENHANDS_SUPPRESS_BANNER", "1")

    from agents.evaluator.fixer.openhands_tools import register_container_tools

    registered_tools = register_container_tools(runtime)
    return run_openhands_agent(
        task_prompt,
        registered_tools,
        run_dir,
        config,
    )


@observe_stage(
    "fixer",
    "export_prediction_patch",
    ignore_inputs=["case", "runtime", "run_dir"],
    log_context=lambda case, runtime, run_dir: (
        f"{case.instance_id} from {runtime.container_name}"
    ),
    output_formatter=lambda patch: json.dumps(
        {"has_patch": bool(patch), "patch_bytes": len(patch.encode("utf-8"))}
    ),
)
def _export_prediction_patch(
    case: CaseDefinition,
    runtime: ContainerRuntime,
    run_dir: Path,
) -> str:
    baseline = runtime.export_fresh_image_files(run_dir / "baseline")
    exported = runtime.export_allowed_files(run_dir / "exported")
    return build_prediction_patch(case, baseline, exported)


@observe_stage(
    "fixer",
    "evaluate_prediction",
    ignore_inputs=["case"],
    log_context=lambda case, patch_path, has_patch: (
        f"{case.instance_id} using {patch_path.name}"
    ),
)
def _evaluate_fixer_patch(
    case: CaseDefinition,
    patch_path: Path,
    *,
    has_patch: bool,
) -> dict[str, object]:
    if not has_patch:
        return {
            "exit_code": 1,
            "stdout": "",
            "stderr": "Agent did not modify an allowed configuration file.",
        }
    return evaluate_prediction(case, patch_path)


def _run_manual_shell(runtime: ContainerRuntime) -> None:
    print(f"[INFO] Opening shell in {runtime.container_name}. Exit to evaluate the repair.")
    subprocess.run(["docker", "exec", "-it", runtime.container_name, "bash"], check=False)


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


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a fixer agent against an isolated MisconfigBench case."
    )
    parser.add_argument("instance_id", nargs="?", default="CA35")
    parser.add_argument("--agent", choices=["openhands", "manual"], default="openhands")
    parser.add_argument("--repair-context", choices=["none", "location", "root_cause"], default="none")
    parser.add_argument(
        "--model",
        default=None,
    )
    parser.add_argument(
        "--llm-provider",
        choices=["openai_subscription", "openlux"],
        default=os.getenv("MISCONFIGBENCH_LLM_PROVIDER", DEFAULT_LLM_PROVIDER),
    )
    parser.add_argument("--api-key")
    parser.add_argument("--base-url")
    parser.add_argument("--subscription-login", action="store_true")
    parser.add_argument("--max-iterations", type=int, default=40)
    parser.add_argument(
        "--agent-timeout",
        type=int,
        default=int(
            os.getenv("MISCONFIGBENCH_AGENT_TIMEOUT_SECONDS", "900")
        ),
        help="Maximum wall-clock seconds for the OpenHands conversation.",
    )
    parser.add_argument("--run-dir")
    parser.add_argument("--keep-container", action="store_true")
    return parser.parse_args(argv)


if __name__ == "__main__":
    sys.exit(run_agent_entrypoint("fixer", main))
