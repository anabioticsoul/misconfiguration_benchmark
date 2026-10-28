from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from agents.manager import (
    CaseDefinition,
    ContainerRuntime,
    capture_agent_exception,
    configure_agent_failure_context,
    create_run_dir,
    load_repository_env,
    run_agent_entrypoint,
)
from agents.manager.paths import instance_dir
from agents.manager.build import DockerInstanceBuilder, InstanceBuildDefinition


REPO_ROOT = Path(__file__).resolve().parents[2]


def main(argv: list[str] | None = None) -> int:
    load_repository_env(REPO_ROOT)
    args = _parse_args(argv)
    configure_agent_failure_context(instance_id=args.instance_id)
    case = CaseDefinition.load(instance_dir(REPO_ROOT, args.instance_id))
    run_dir = create_run_dir(
        REPO_ROOT, f"builder-validation-{args.instance_id}", args.run_dir
    )
    run_dir.mkdir(parents=True, exist_ok=False)
    configure_agent_failure_context(
        instance_id=args.instance_id,
        run_dir=run_dir,
    )
    result: dict[str, object] = {
        "instance_id": case.instance_id,
        "run_dir": str(run_dir),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "agent_role": "builder_validation",
        "image": case.image_name,
        "success": False,
    }

    try:
        case.validate_files()
        reproduce_path = case.case_dir / case.reproduce_script
        reference_patch = case.case_dir / case.reference_patch
        if not reproduce_path.is_file():
            raise FileNotFoundError(f"Reproduction script not found: {reproduce_path}")
        if not reference_patch.is_file():
            raise FileNotFoundError(f"Reference patch not found: {reference_patch}")

        ContainerRuntime(case)._ensure_image()
        result.update(DockerInstanceBuilder(
            InstanceBuildDefinition.load(case), run_dir
        ).validate(timeout_seconds=args.timeout))
        return 0 if result["success"] else 1
    except Exception as exc:  # noqa: BLE001
        result["error"] = f"{type(exc).__name__}: {exc}"
        capture_agent_exception(exc)
        return 1
    finally:
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
        result_path = run_dir / "result.json"
        result_path.write_text(
            json.dumps(result, indent=2, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(result, indent=2, ensure_ascii=True))


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Verify that a MisconfigBench image reproduces its description and "
            "passes reference F2P/P2P evaluation."
        )
    )
    parser.add_argument("instance_id")
    parser.add_argument("--run-dir")
    parser.add_argument("--timeout", type=int, default=120)
    return parser.parse_args(argv)


if __name__ == "__main__":
    sys.exit(run_agent_entrypoint("builder_validation", main))
