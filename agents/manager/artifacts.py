"""Shared run-directory and prediction artifact helpers."""

from __future__ import annotations

import difflib
from datetime import datetime
from pathlib import Path

from agents.manager.case import CaseDefinition


def create_run_dir(
    repo_root: Path,
    instance_id: str,
    configured: str | None = None,
) -> Path:
    if configured:
        return Path(configured).resolve()
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    return repo_root / "runs" / f"{timestamp}-{instance_id.lower()}"


def build_prediction_patch(
    case: CaseDefinition,
    baseline_files: dict[str, Path],
    exported_files: dict[str, Path],
) -> str:
    chunks: list[str] = []
    for relative_path in case.allowed_modified_files:
        baseline = baseline_files[relative_path].read_text(encoding="utf-8")
        modified = exported_files[relative_path].read_text(encoding="utf-8")
        chunks.extend(
            difflib.unified_diff(
                baseline.splitlines(keepends=True),
                modified.splitlines(keepends=True),
                fromfile=f"a/{relative_path}",
                tofile=f"b/{relative_path}",
            )
        )
    return "".join(chunks)
