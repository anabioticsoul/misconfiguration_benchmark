"""Shared host-side evaluator invocation."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from agents.manager.case import CaseDefinition


def evaluate_prediction(case: CaseDefinition, patch_path: Path) -> dict[str, object]:
    environment = os.environ.copy()
    platform = _inspect_image_platform(case.image_name)
    if platform:
        environment["DOCKER_DEFAULT_PLATFORM"] = platform
    completed = subprocess.run(
        [str(case.evaluator), str(patch_path), case.image_name],
        capture_output=True,
        text=True,
        check=False,
        env=environment,
    )
    return {
        "exit_code": completed.returncode,
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
