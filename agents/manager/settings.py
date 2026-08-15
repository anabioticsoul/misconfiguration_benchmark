"""Repository-local configuration loading."""

from __future__ import annotations

from pathlib import Path

from dotenv import load_dotenv


def load_repository_env(repo_root: Path) -> bool:
    """Load an ignored .env file without replacing explicit environment values."""
    return load_dotenv(repo_root / ".env", override=False)


__all__ = ["load_repository_env"]
