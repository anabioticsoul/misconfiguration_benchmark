"""Canonical repository paths for benchmark instances."""

from __future__ import annotations

import re
from pathlib import Path


_CASE_ID = re.compile(r"^(CA|CB|CC|CD)\d+$", re.IGNORECASE)


def instance_dir(repo_root: Path, instance_id: str) -> Path:
    """Return the category-grouped directory for a benchmark instance."""
    normalized_id = instance_id.upper()
    match = _CASE_ID.fullmatch(normalized_id)
    if not match:
        raise ValueError(
            f"Invalid instance ID {instance_id!r}; expected CA, CB, CC, or CD "
            "followed by digits"
        )
    return repo_root / "instances" / match.group(1) / normalized_id


__all__ = ["instance_dir"]
