from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from agents.manager import (
    CaseDefinition,
    ContainerRuntime,
    create_run_dir,
    evaluate_prediction,
    load_repository_env,
    observe_stage,
)


REPO_ROOT = Path(__file__).resolve().parents[2]


def main(argv: list[str] | None = None) -> int:
    load_repository_env(REPO_ROOT)
    args = _parse_args(argv)
    case = CaseDefinition.load(REPO_ROOT / "instances" / args.instance_id)
    run_dir = create_run_dir(
        REPO_ROOT, f"verifier-{args.instance_id}", args.run_dir
    )
    run_dir.mkdir(parents=True, exist_ok=False)
    result: dict[str, object] = {
        "instance_id": case.instance_id,
        "run_dir": str(run_dir),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "agent_role": "verifier",
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

        reproduction = _run_reproduction(case, reproduce_path, args.timeout)
        evaluation = _evaluate_reference_patch(case, reference_patch)
        result["reproduction"] = {
            "exit_code": reproduction.exit_code,
            "stdout": reproduction.stdout,
            "stderr": reproduction.stderr,
        }
        result["reference_evaluation"] = evaluation
        result["success"] = (
            reproduction.exit_code == 0 and evaluation["exit_code"] == 0
        )
        return 0 if result["success"] else 1
    except Exception as exc:  # noqa: BLE001
        result["error"] = f"{type(exc).__name__}: {exc}"
        return 1
    finally:
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
        result_path = run_dir / "result.json"
        result_path.write_text(
            json.dumps(result, indent=2, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(result, indent=2, ensure_ascii=True))


@observe_stage(
    "verifier",
    "reproduce_failure",
    ignore_inputs=["case", "reproduce_path"],
)
def _run_reproduction(
    case: CaseDefinition,
    reproduce_path: Path,
    timeout: int,
):
    with ContainerRuntime(case) as runtime:
        runtime.copy_file(reproduce_path, "/tmp/misconfigbench-reproduce.sh")
        return runtime.execute(
            "bash /tmp/misconfigbench-reproduce.sh",
            timeout_seconds=timeout,
        )


@observe_stage(
    "verifier",
    "evaluate_reference_patch",
    ignore_inputs=["case"],
)
def _evaluate_reference_patch(
    case: CaseDefinition,
    reference_patch: Path,
) -> dict[str, object]:
    return evaluate_prediction(case, reference_patch)


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
    sys.exit(main())
