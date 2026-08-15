from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from agents.fixer.prompts import render_case_prompt, resolve_prompt_template
from agents.manager import (
    CaseDefinition,
    ContainerRuntime,
    DEFAULT_SUBSCRIPTION_MODEL,
    OpenHandsConfig,
    build_prediction_patch,
    create_run_dir,
    evaluate_prediction,
    load_repository_env,
    observe_stage,
    run_openhands_agent,
)


REPO_ROOT = Path(__file__).resolve().parents[2]


def main(argv: list[str] | None = None) -> int:
    load_repository_env(REPO_ROOT)
    args = _parse_args(argv)
    case = CaseDefinition.load(REPO_ROOT / "instances" / args.instance_id)
    run_dir = create_run_dir(REPO_ROOT, args.instance_id, args.run_dir)
    run_dir.mkdir(parents=True, exist_ok=False)

    result = {
        "instance_id": case.instance_id,
        "run_dir": str(run_dir),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "agent": args.agent,
        "agent_role": "fixer",
        "prompt_template": str(resolve_prompt_template(case)),
        "success": False,
    }
    try:
        task_prompt = render_case_prompt(case)
        task_prompt_path = run_dir / "task_prompt.md"
        task_prompt_path.write_text(task_prompt, encoding="utf-8")
        result["task_prompt"] = str(task_prompt_path)

        with ContainerRuntime(case, keep_container=args.keep_container) as runtime:
            result["container_name"] = runtime.container_name
            if args.agent == "manual":
                _run_manual_shell(runtime)
            else:
                result["agent_response"] = _run_openhands_agent(
                    task_prompt,
                    runtime,
                    run_dir,
                    _openhands_config(args),
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
    except Exception as exc:  # noqa: BLE001
        result["error"] = f"{type(exc).__name__}: {exc}"
        return 1
    finally:
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

    from agents.fixer.openhands_tools import register_container_tools

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
    return OpenHandsConfig(
        model=args.model,
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
    parser.add_argument(
        "--model",
        default=os.getenv("LLM_MODEL", DEFAULT_SUBSCRIPTION_MODEL),
    )
    parser.add_argument("--api-key", default=os.getenv("LLM_API_KEY"))
    parser.add_argument("--base-url", default=os.getenv("LLM_BASE_URL"))
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
    sys.exit(main())
