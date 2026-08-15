"""Shared Docker runtime for benchmark case environments."""

from __future__ import annotations

import base64
import json
import shlex
import subprocess
import time
import uuid
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

from agents.manager.case import CaseDefinition


class RuntimeErrorWithOutput(RuntimeError):
    pass


@dataclass(frozen=True)
class CommandResult:
    exit_code: int
    stdout: str
    stderr: str

    def render(self) -> str:
        parts = [f"exit_code: {self.exit_code}"]
        if self.stdout:
            parts.extend(["stdout:", self.stdout.rstrip()])
        if self.stderr:
            parts.extend(["stderr:", self.stderr.rstrip()])
        return "\n".join(parts)


class ContainerRuntime:
    def __init__(
        self,
        case: CaseDefinition,
        *,
        container_name: str | None = None,
        keep_container: bool = False,
    ) -> None:
        self.case = case
        self.container_name = container_name or self._new_container_name()
        self.keep_container = keep_container
        self.started = False

    def __enter__(self) -> "ContainerRuntime":
        self.start()
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def start(self) -> None:
        self.case.validate_files()
        self._require_docker()
        self._ensure_image()
        self._run(self.case.docker_create_command(self.container_name))
        self.started = True
        try:
            self._run(["docker", "start", self.container_name])
            self._wait_until_ready()
        except Exception:
            self.close()
            raise

    def close(self) -> None:
        if self.started and not self.keep_container:
            self._run(["docker", "rm", "-f", self.container_name], check=False)
            self.started = False

    def execute(self, command: str, *, timeout_seconds: int = 30) -> CommandResult:
        completed = self._run(
            ["docker", "exec", self.container_name, "bash", "-lc", command],
            check=False,
            timeout_seconds=timeout_seconds,
        )
        return CommandResult(completed.returncode, completed.stdout, completed.stderr)

    def read_file(self, path: str) -> str:
        container_path = self._absolute_path(path)
        completed = self._run(
            ["docker", "exec", self.container_name, "cat", "--", container_path],
            check=False,
        )
        if completed.returncode != 0:
            raise RuntimeErrorWithOutput(completed.stderr or completed.stdout)
        return completed.stdout

    def copy_file(self, source: Path, destination: str) -> None:
        if not source.is_file():
            raise FileNotFoundError(f"Host file not found: {source}")
        container_path = self._absolute_path(destination)
        self._run(
            [
                "docker",
                "cp",
                str(source),
                f"{self.container_name}:{container_path}",
            ]
        )

    def write_file(self, path: str, content: str) -> None:
        container_path = self._absolute_path(path)
        payload = base64.b64encode(content.encode("utf-8"))
        completed = self._run(
            [
                "docker",
                "exec",
                "-i",
                self.container_name,
                "bash",
                "-lc",
                f"base64 -d > {shlex.quote(container_path)}",
            ],
            input_bytes=payload,
            check=False,
        )
        if completed.returncode != 0:
            raise RuntimeErrorWithOutput(completed.stderr or completed.stdout)

    def export_allowed_files(self, destination: Path) -> dict[str, Path]:
        exported: dict[str, Path] = {}
        for relative_path in self.case.allowed_modified_files:
            host_path = destination / relative_path
            host_path.parent.mkdir(parents=True, exist_ok=True)
            self._run(
                [
                    "docker",
                    "cp",
                    f"{self.container_name}:/{relative_path}",
                    str(host_path),
                ]
            )
            exported[relative_path] = host_path
        return exported

    def export_fresh_image_files(self, destination: Path) -> dict[str, Path]:
        baseline_container = f"{self.container_name}-baseline"
        try:
            self._run(["docker", "create", "--name", baseline_container, self.case.image_name])
            exported: dict[str, Path] = {}
            for relative_path in self.case.allowed_modified_files:
                host_path = destination / relative_path
                host_path.parent.mkdir(parents=True, exist_ok=True)
                self._run(
                    [
                        "docker",
                        "cp",
                        f"{baseline_container}:/{relative_path}",
                        str(host_path),
                    ]
                )
                exported[relative_path] = host_path
            return exported
        finally:
            self._run(["docker", "rm", "-f", baseline_container], check=False)

    def _ensure_image(self) -> None:
        inspected = self._run(
            ["docker", "image", "inspect", self.case.image_name],
            check=False,
        )
        if inspected.returncode == 0 and _inspect_has_start_command(inspected.stdout):
            return
        pull_error = ""
        pull_reference = self.case.image_distribution.get("pull_reference")
        if inspected.returncode != 0 and pull_reference:
            pulled = self._run(
                ["docker", "pull", pull_reference],
                check=False,
                timeout_seconds=1800,
            )
            if pulled.returncode == 0:
                self._run(
                    ["docker", "tag", pull_reference, self.case.image_name]
                )
                distributed = self._run(
                    ["docker", "image", "inspect", self.case.image_name],
                    check=False,
                )
                if (
                    distributed.returncode == 0
                    and _inspect_has_start_command(distributed.stdout)
                ):
                    return
                pull_error = (
                    "Registry image was pulled but has no ENTRYPOINT or CMD: "
                    f"{pull_reference}"
                )
            else:
                pull_error = pulled.stderr or pulled.stdout
        if not self.case.image_archive.is_file():
            if inspected.returncode == 0:
                raise RuntimeErrorWithOutput(
                    f"Docker image {self.case.image_name} has no ENTRYPOINT or CMD, "
                    f"and its replacement archive was not found: {self.case.image_archive}"
                )
            detail = f"\nRegistry pull failed:\n{pull_error}" if pull_error else ""
            raise FileNotFoundError(
                f"Image archive not found: {self.case.image_archive}{detail}"
            )

        if self.case.image_archive_format not in {"docker_save_tar", "docker_save_tar_gzip"}:
            raise ValueError(
                f"Unsupported image archive format: {self.case.image_archive_format}"
            )

        self._run(["docker", "load", "-i", str(self.case.image_archive)], timeout_seconds=300)
        loaded = self._run(
            ["docker", "image", "inspect", self.case.image_name],
            check=False,
        )
        if loaded.returncode != 0:
            raise RuntimeErrorWithOutput(
                "Image archive loaded, but expected tag was not found: "
                f"{self.case.image_name}"
            )
        if not _inspect_has_start_command(loaded.stdout):
            raise RuntimeErrorWithOutput(
                f"Image archive loaded {self.case.image_name}, but the image has no "
                "ENTRYPOINT or CMD"
            )

    def _require_docker(self) -> None:
        completed = self._run(["docker", "info"], check=False)
        if completed.returncode != 0:
            raise RuntimeErrorWithOutput(
                "Docker daemon is unavailable.\n" + (completed.stderr or completed.stdout)
            )

    def _wait_until_ready(self) -> None:
        deadline = time.monotonic() + self.case.ready_timeout_seconds
        while time.monotonic() < deadline:
            if not self._is_running():
                break
            if self.execute(self.case.ready_check, timeout_seconds=5).exit_code == 0:
                return
            time.sleep(1)
        logs = self._run(
            ["docker", "logs", self.container_name],
            check=False,
        )
        raise RuntimeErrorWithOutput(
            "Container did not become ready.\n" + logs.stdout + logs.stderr
        )

    def _is_running(self) -> bool:
        completed = self._run(
            [
                "docker",
                "inspect",
                "--format",
                "{{.State.Running}}",
                self.container_name,
            ],
            check=False,
        )
        return completed.returncode == 0 and completed.stdout.strip() == "true"

    def _run(
        self,
        command: list[str],
        *,
        check: bool = True,
        input_bytes: bytes | None = None,
        timeout_seconds: int = 30,
    ) -> subprocess.CompletedProcess[str]:
        try:
            completed = subprocess.run(
                command,
                input=input_bytes,
                capture_output=True,
                timeout=timeout_seconds,
                check=False,
            )
        except subprocess.TimeoutExpired as exc:
            raise RuntimeErrorWithOutput(f"Command timed out: {shlex.join(command)}") from exc

        result = subprocess.CompletedProcess(
            completed.args,
            completed.returncode,
            completed.stdout.decode("utf-8", errors="replace"),
            completed.stderr.decode("utf-8", errors="replace"),
        )
        if check and result.returncode != 0:
            raise RuntimeErrorWithOutput(
                f"Command failed: {shlex.join(command)}\n{result.stdout}{result.stderr}"
            )
        return result

    @staticmethod
    def _absolute_path(path: str) -> str:
        if not path.startswith("/"):
            raise ValueError("Container file paths must be absolute")
        normalized = PurePosixPath(path)
        if ".." in normalized.parts:
            raise ValueError("Container file path escapes root")
        return normalized.as_posix()

    def _new_container_name(self) -> str:
        suffix = uuid.uuid4().hex[:10]
        return f"misconfigbench-{self.case.instance_id.lower()}-{suffix}"


def _inspect_has_start_command(output: str) -> bool:
    try:
        images = json.loads(output)
        config = images[0]["Config"]
    except (IndexError, KeyError, TypeError, json.JSONDecodeError):
        return False
    return bool(config.get("Entrypoint") or config.get("Cmd"))
