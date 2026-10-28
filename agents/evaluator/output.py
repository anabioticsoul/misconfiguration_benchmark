"""Output identity and paths shared by evaluation tasks."""

from __future__ import annotations

import hashlib
import re
from pathlib import Path

from agents.manager import OpenHandsConfig, create_run_dir


def experiment_identity(
    config: OpenHandsConfig | None, *, mode: str = "live"
) -> dict[str, object]:
    if config is None:
        return {"mode": mode, "provider": mode, "model": "unknown" if mode == "offline" else "none"}
    return {
        "mode": mode,
        "provider": config.provider,
        "model": config.model,
        "max_iterations": config.max_iterations,
        "agent_timeout": config.max_runtime_seconds,
    }


def _path_component(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9_.-]+", "-", value).strip(".-")[:80] or "unknown"
    if slug != value:
        # Keep distinct model IDs such as openai/x and openai-x separate.
        slug += "-" + hashlib.sha256(value.encode("utf-8")).hexdigest()[:12]
    return slug


def evaluation_run_dir(
    repo_root: Path,
    task: str,
    instance_id: str,
    experiment: dict[str, object],
    configured: str | None = None,
) -> Path:
    if configured:
        return Path(configured).resolve()
    group = (
        repo_root / "runs" / task
        / _path_component(str(experiment["provider"]))
        / _path_component(str(experiment["model"]))
    )
    for field in ("repair_context", "evidence_mode", "evidence_condition"):
        if field in experiment:
            group /= _path_component(f"{field}-{experiment[field]}")
    return group / create_run_dir(repo_root, instance_id).name
