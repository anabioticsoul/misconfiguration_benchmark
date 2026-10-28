"""Shared host-side evaluator invocation."""

from __future__ import annotations

import os
import json
import subprocess
import tempfile
from pathlib import Path

from agents.manager.case import CaseDefinition


def evaluate_prediction(case: CaseDefinition, patch_path: Path) -> dict[str, object]:
    environment = os.environ.copy()
    platform = _inspect_image_platform(case.image_name)
    if platform:
        environment["DOCKER_DEFAULT_PLATFORM"] = platform
    checks = {key: "not_evaluated" for key in ("patch_apply", "policy", "f2p", "p2p", "safety")}
    with tempfile.TemporaryDirectory(prefix="misconfig-eval-") as temporary:
        check_file = Path(temporary) / "checks.json"
        environment["MISCONFIGBENCH_EVALUATION_RESULT"] = str(check_file)
        completed = subprocess.run(
            [str(case.evaluator), str(patch_path), case.image_name],
            capture_output=True,
            text=True,
            check=False,
            env=environment,
        )
        if check_file.exists():
            document = json.loads(check_file.read_text())
            if not isinstance(document, dict) or set(document) - checks.keys():
                raise ValueError("Invalid structured harness checks")
            if any(value not in ("pass", "fail", "not_evaluated") for value in document.values()):
                raise ValueError("Invalid structured harness verdict")
            checks.update(document)
    exit_code = completed.returncode or int("fail" in checks.values())
    return {
        "exit_code": exit_code,
        "checks": checks,
        "harness_success": exit_code == 0,
        "functional_success": (checks["f2p"] == checks["p2p"] == "pass")
            if "not_evaluated" not in (checks["f2p"], checks["p2p"]) else None,
        "safe_success": (exit_code == 0 and all(value == "pass" for value in checks.values()))
            if all(value != "not_evaluated" for value in checks.values()) else None,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }


def _inspect_image_platform(image_name: str) -> str | None:
    completed = subprocess.run(
        [
            "docker",
            "image",
            "inspect",
            "--format",
            "{{.Os}}/{{.Architecture}}",
            image_name,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    platform = completed.stdout.strip()
    if completed.returncode != 0 or "/" not in platform:
        return None
    return platform
