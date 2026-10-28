"""Repository-local configuration loading."""

from __future__ import annotations

import os
import platform
import re
import subprocess
from pathlib import Path

from dotenv import load_dotenv


def load_repository_env(repo_root: Path) -> bool:
    """Load local configuration and inherit a configured macOS proxy."""
    loaded = load_dotenv(repo_root / ".env", override=False)
    _inherit_macos_system_proxy()
    return loaded


def _inherit_macos_system_proxy() -> None:
    """Expose macOS's HTTP(S) proxy to clients that only honor env variables."""
    if platform.system() != "Darwin":
        return
    if os.environ.get("HTTP_PROXY") and os.environ.get("HTTPS_PROXY"):
        return

    try:
        completed = subprocess.run(
            ["scutil", "--proxy"],
            capture_output=True,
            text=True,
            check=False,
            timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        return
    if completed.returncode != 0:
        return

    values = _parse_macos_proxy_settings(completed.stdout)
    for scheme in ("HTTP", "HTTPS"):
        environment_key = f"{scheme}_PROXY"
        if os.environ.get(environment_key):
            continue
        if values.get(f"{scheme}Enable") != "1":
            continue
        host = values.get(f"{scheme}Proxy")
        port = values.get(f"{scheme}Port")
        if host and port and port.isdecimal():
            os.environ[environment_key] = f"http://{host}:{port}"


def _parse_macos_proxy_settings(output: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in output.splitlines():
        match = re.match(r"^\s*(HTTP(?:S)?(?:Enable|Proxy|Port))\s*:\s*(.*?)\s*$", line)
        if match:
            values[match.group(1)] = match.group(2)
    return values


__all__ = ["load_repository_env"]
