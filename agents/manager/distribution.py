"""Docker registry distribution for validated benchmark images."""

from __future__ import annotations

import json
import re
import shlex
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from agents.manager.container_runtime import RuntimeErrorWithOutput
from agents.manager.observability import observe_stage


_SAFE_COMPONENT = re.compile(r"^[a-z0-9]+(?:[._-][a-z0-9]+)*$")
_DIGEST = re.compile(r"sha256:[0-9a-f]{64}")


@dataclass(frozen=True)
class RegistryConfig:
    namespace: str
    registry: str = "docker.io"
    repository_prefix: str = "misconfigbench"
    tag: str | None = None

    def image_reference(self, instance_id: str, benchmark_version: str) -> str:
        namespace = self.namespace.strip().strip("/")
        registry = self.registry.strip().rstrip("/")
        prefix = self.repository_prefix.strip().lower()
        case_id = instance_id.strip().lower()
        tag = (self.tag or f"v{benchmark_version}").strip().lower()
        for label, value in (
            ("registry namespace", namespace),
            ("repository prefix", prefix),
            ("instance ID", case_id),
            ("image tag", tag),
        ):
            if not value or not _SAFE_COMPONENT.fullmatch(value):
                raise ValueError(f"Invalid {label}: {value!r}")
        if not registry:
            raise ValueError("Docker registry must not be empty")
        return f"{registry}/{namespace}/{prefix}-{case_id}:{tag}"


@observe_stage(
    "distribution",
    "login_registry",
    ignore_inputs=["token"],
    log_context=lambda registry, username, token: f"{username}@{registry}",
)
def login_registry(registry: str, username: str, token: str) -> None:
    """Authenticate Docker without exposing the token in process arguments."""
    if not username.strip() or not token:
        raise ValueError("Docker registry username and token must both be set")
    completed = subprocess.run(
        [
            "docker",
            "login",
            registry,
            "--username",
            username,
            "--password-stdin",
        ],
        input=token,
        capture_output=True,
        text=True,
        check=False,
        timeout=120,
    )
    if completed.returncode != 0:
        raise RuntimeErrorWithOutput(
            f"Docker login failed for {username}@{registry}\n"
            f"{completed.stdout}{completed.stderr}"
        )


@observe_stage(
    "builder",
    "push_registry_image",
    ignore_inputs=["config"],
    log_context=lambda local_image, instance_id, benchmark_version, config: (
        f"{local_image} -> "
        f"{config.image_reference(instance_id, benchmark_version)}"
    ),
)
def push_registry_image(
    local_image: str,
    instance_id: str,
    benchmark_version: str,
    config: RegistryConfig,
) -> dict[str, str]:
    """Tag and push one validated image, returning immutable distribution data."""
    reference = config.image_reference(instance_id, benchmark_version)
    _run(["docker", "image", "inspect", local_image])
    _run(["docker", "tag", local_image, reference])
    pushed = _run(["docker", "push", reference], timeout_seconds=1800)
    digest_match = _DIGEST.search(pushed.stdout + pushed.stderr)
    digest = digest_match.group(0) if digest_match else _inspect_digest(reference)
    repository = reference.rsplit(":", 1)[0]
    return {
        "type": "docker_registry",
        "reference": reference,
        "digest": digest,
        "pull_reference": f"{repository}@{digest}",
    }


def record_image_distribution(
    manifest_path: Path,
    distribution: dict[str, str],
) -> None:
    manifest: dict[str, Any] = json.loads(
        manifest_path.read_text(encoding="utf-8")
    )
    image = manifest.get("image")
    if not isinstance(image, dict):
        raise ValueError(f"{manifest_path}: image must be an object")
    image["distribution"] = distribution
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )


def _inspect_digest(reference: str) -> str:
    inspected = _run(
        [
            "docker",
            "image",
            "inspect",
            "--format",
            "{{json .RepoDigests}}",
            reference,
        ]
    )
    values = json.loads(inspected.stdout)
    for value in values or []:
        match = _DIGEST.search(value)
        if match:
            return match.group(0)
    raise RuntimeErrorWithOutput(
        f"Docker push succeeded but no repository digest was found for {reference}"
    )


def _run(
    command: list[str],
    *,
    timeout_seconds: int = 120,
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
        timeout=timeout_seconds,
    )
    if completed.returncode != 0:
        raise RuntimeErrorWithOutput(
            f"Command failed: {shlex.join(command)}\n"
            f"{completed.stdout}{completed.stderr}"
        )
    return completed


__all__ = [
    "RegistryConfig",
    "login_registry",
    "push_registry_image",
    "record_image_distribution",
]
