from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from benchmark.case import CaseDefinition, build_prediction_patch
from benchmark.container_runtime import ContainerRuntime, RuntimeErrorWithOutput


REPO_ROOT = Path(__file__).resolve().parents[1]


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    case = CaseDefinition.load(REPO_ROOT / "instances" / args.instance_id)
    run_dir = _new_run_dir(args.instance_id, args.run_dir)
    run_dir.mkdir(parents=True, exist_ok=False)

    result = {
        "instance_id": case.instance_id,
        "run_dir": str(run_dir),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "agent": args.agent,
        "success": False,
    }
    try:
        with ContainerRuntime(case, keep_container=args.keep_container) as runtime:
            result["container_name"] = runtime.container_name
            if args.agent == "manual":
                _run_manual_shell(runtime)
            else:
                result["agent_response"] = _run_openhands_agent(
                    case,
                    runtime,
                    run_dir,
                    args,
                )

            exported = runtime.export_allowed_files(run_dir / "exported")
            patch = build_prediction_patch(case, exported)
            patch_path = run_dir / "prediction.diff"
            patch_path.write_text(patch, encoding="utf-8")
            result["prediction_patch"] = str(patch_path)

        if not patch:
            result["evaluation"] = {
                "exit_code": 1,
                "stdout": "",
                "stderr": "Agent did not modify an allowed configuration file.",
            }
        else:
            result["evaluation"] = _evaluate(case, patch_path)
        result["success"] = result["evaluation"]["exit_code"] == 0
        return 0 if result["success"] else 1
    except (FileNotFoundError, RuntimeErrorWithOutput, ValueError) as exc:
        result["error"] = str(exc)
        return 1
    finally:
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
        (run_dir / "result.json").write_text(
            json.dumps(result, indent=2, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(result, indent=2, ensure_ascii=True))


def _run_openhands_agent(
    case: CaseDefinition,
    runtime: ContainerRuntime,
    run_dir: Path,
    args: argparse.Namespace,
) -> str:
    os.environ.setdefault("OPENHANDS_SUPPRESS_BANNER", "1")
    from openhands.sdk import Agent, Conversation, LLM, Tool
    from openhands.sdk.conversation.response_utils import get_agent_final_response

    from benchmark.openhands_tools import register_container_tools

    registered_tools = register_container_tools(runtime)
    if args.subscription_login:
        llm = LLM.subscription_login(vendor="openai", model=args.model)
    else:
        llm = LLM(
            model=args.model,
            api_key=args.api_key,
            base_url=args.base_url,
        )

    trajectory = (run_dir / "trajectory.jsonl").open("w", encoding="utf-8")

    def record_event(event) -> None:  # noqa: ANN001
        trajectory.write(event.model_dump_json(exclude_none=True) + "\n")
        trajectory.flush()

    agent = Agent(
        llm=llm,
        tools=[Tool(name=name) for name in registered_tools],
        include_default_tools=["ThinkTool", "FinishTool"],
    )
    workspace = run_dir / "agent_workspace"
    workspace.mkdir()
    conversation = Conversation(
        agent=agent,
        workspace=workspace,
        callbacks=[record_event],
        max_iteration_per_run=args.max_iterations,
        visualizer=None,
    )
    try:
        conversation.send_message(case.read_public_problem())
        conversation.run()
        return get_agent_final_response(conversation.events)
    finally:
        conversation.close()
        trajectory.close()


def _run_manual_shell(runtime: ContainerRuntime) -> None:
    print(f"[INFO] Opening shell in {runtime.container_name}. Exit to evaluate the repair.")
    subprocess.run(["docker", "exec", "-it", runtime.container_name, "bash"], check=False)


def _evaluate(case: CaseDefinition, patch_path: Path) -> dict:
    completed = subprocess.run(
        [str(case.evaluator), str(patch_path), case.image_name],
        capture_output=True,
        text=True,
        check=False,
    )
    return {
        "exit_code": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }


def _new_run_dir(instance_id: str, configured: str | None) -> Path:
    if configured:
        return Path(configured).resolve()
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return REPO_ROOT / "runs" / f"{timestamp}-{instance_id.lower()}"


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run an agent directly against an isolated MisconfigBench case."
    )
    parser.add_argument("instance_id", nargs="?", default="CA35")
    parser.add_argument("--agent", choices=["openhands", "manual"], default="openhands")
    parser.add_argument("--model", default=os.getenv("LLM_MODEL", "gpt-5.2-codex"))
    parser.add_argument("--api-key", default=os.getenv("LLM_API_KEY"))
    parser.add_argument("--base-url", default=os.getenv("LLM_BASE_URL"))
    parser.add_argument("--subscription-login", action="store_true")
    parser.add_argument("--max-iterations", type=int, default=40)
    parser.add_argument("--run-dir")
    parser.add_argument("--keep-container", action="store_true")
    return parser.parse_args(argv)


if __name__ == "__main__":
    sys.exit(main())

