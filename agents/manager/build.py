"""Deterministic Docker image construction and validation."""

from __future__ import annotations

import gzip
import json
import os
import re
import selectors
import shlex
import subprocess
import tempfile
import time
import uuid
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

from agents.manager.case import CaseDefinition
from agents.manager.container_runtime import RuntimeErrorWithOutput
from agents.manager.observability import observe_stage
from agents.manager.templates import render_template
from openhands.sdk.logger import get_logger


logger = get_logger(__name__)
_BENCHMARK_CASE_IMAGE = re.compile(r"^(?:ca|cb|cc|cd)\d+:", re.IGNORECASE)
_KNOWN_SOFTWARE_IMAGES = {
    "httpd",
    "mariadb",
    "mongo",
    "mysql",
    "nginx",
    "php",
    "postgres",
    "rabbitmq",
    "redis",
}


@dataclass(frozen=True)
class InstanceBuildDefinition:
    case: CaseDefinition
    build_root: Path
    source_image: str
    base_image: str
    output_image: str
    base_dockerfile_template: Path
    instance_dockerfile_template: Path
    context_dir: Path
    requirements: Path
    archive: Path
    base_script: Path | None
    instance_script: Path | None

    @classmethod
    def load(
        cls,
        case: CaseDefinition,
        build_root: Path | None = None,
    ) -> "InstanceBuildDefinition":
        configured = case.builder_protocol
        if not configured:
            raise ValueError(f"{case.instance_id} does not define builder_protocol")

        source_root = build_root.resolve() if build_root else case.case_dir
        spec_path = _contained_path(source_root, configured["spec"])
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
        images = spec["images"]
        template_root = case.repo_root / "templates" / "builder"

        definition = cls(
            case=case,
            build_root=source_root,
            source_image=images["source"],
            base_image=images["base"],
            output_image=images["output"],
            base_dockerfile_template=template_root / "Dockerfile.base.j2",
            instance_dockerfile_template=template_root / "Dockerfile.instance.j2",
            context_dir=_contained_path(source_root, spec["context_dir"]),
            requirements=_contained_path(
                source_root, configured["requirements"]
            ),
            archive=_contained_path(
                case.case_dir,
                spec.get("archive", f"image/{case.instance_id}.tar.gz"),
            ),
            base_script=_optional_contained_path(
                source_root, spec.get("scripts", {}).get("base")
            ),
            instance_script=_optional_contained_path(
                source_root, spec.get("scripts", {}).get("instance")
            ),
        )
        definition.validate_files(spec_path)
        return definition

    def validate_files(self, spec_path: Path) -> None:
        required = [
            spec_path,
            self.base_dockerfile_template,
            self.instance_dockerfile_template,
            self.context_dir,
            self.requirements,
        ]
        required.extend(
            path for path in (self.base_script, self.instance_script) if path
        )
        missing = [str(path) for path in required if not path.exists()]
        if missing:
            raise FileNotFoundError("Missing builder files:\n" + "\n".join(missing))
        for script in (self.base_script, self.instance_script):
            if script and self.context_dir not in script.parents:
                raise ValueError(
                    f"Build script must be inside context_dir: {script}"
                )
        if self.output_image != self.case.image_name:
            raise ValueError(
                "Builder output image must match instance image: "
                f"{self.output_image} != {self.case.image_name}"
            )
        if self.source_image == self.base_image:
            raise ValueError(
                "Builder source image must not equal the base output image: "
                f"{self.source_image}"
            )
        if _BENCHMARK_CASE_IMAGE.match(self.source_image):
            raise ValueError(
                "Builder source image must be an independent clean image, not "
                f"another benchmark case image: {self.source_image}"
            )
        repository = self.source_image.split(":", 1)[0].rsplit("/", 1)[-1]
        software_tokens = {
            token
            for token in re.findall(
                r"[a-z0-9]+",
                self.case.software_name.lower(),
            )
            if len(token) > 2
        }
        if self.source_image.lower().startswith("misconfigbench/"):
            if software_tokens and not any(
                token in repository.lower() for token in software_tokens
            ):
                raise ValueError(
                    "Purpose-built source image does not match target software "
                    f"{self.case.software_name!r}: {self.source_image}"
                )
        if (
            repository.lower() in _KNOWN_SOFTWARE_IMAGES
            and repository.lower() not in software_tokens
        ):
            raise ValueError(
                "Official software source image does not match target software "
                f"{self.case.software_name!r}: {self.source_image}"
            )


class DockerInstanceBuilder:
    def __init__(
        self,
        definition: InstanceBuildDefinition,
        run_dir: Path,
        *,
        no_cache: bool = False,
    ) -> None:
        self.definition = definition
        self.run_dir = run_dir
        self.no_cache = no_cache
        self.log_path = run_dir / "docker_build.log"

    @observe_stage(
        "builder",
        "build_image",
        ignore_inputs=["self"],
        heartbeat_seconds=0,
        log_context=lambda self: (
            f"{self.definition.case.instance_id}: "
            f"{self.definition.source_image} -> "
            f"{self.definition.base_image} -> "
            f"{self.definition.output_image}"
        ),
    )
    def build(self) -> dict[str, object]:
        self._ensure_source_image()
        platform = self._source_platform()
        rendered_dir = self.run_dir / "rendered"
        rendered_dir.mkdir(parents=True, exist_ok=True)

        base_dockerfile = self._render_dockerfile(
            self.definition.base_dockerfile_template,
            rendered_dir / "Dockerfile.base",
            {
                "source_image": self.definition.source_image,
                "base_image": self.definition.base_image,
                "output_image": self.definition.output_image,
                "build_script": (
                    self.definition.base_script.relative_to(
                        self.definition.context_dir
                    ).as_posix()
                    if self.definition.base_script
                    else ""
                ),
            },
        )
        instance_dockerfile = self._render_dockerfile(
            self.definition.instance_dockerfile_template,
            rendered_dir / "Dockerfile.instance",
            {
                "source_image": self.definition.source_image,
                "base_image": self.definition.base_image,
                "output_image": self.definition.output_image,
                "build_script": (
                    self.definition.instance_script.relative_to(
                        self.definition.context_dir
                    ).as_posix()
                    if self.definition.instance_script
                    else ""
                ),
            },
        )

        self.log_path.write_text("", encoding="utf-8")
        logger.info(
            "Building clean base image %s from %s",
            self.definition.base_image,
            self.definition.source_image,
        )
        self._docker_build(
            base_dockerfile, self.definition.base_image, platform=platform
        )
        logger.info(
            "Building faulty instance image %s from %s",
            self.definition.output_image,
            self.definition.base_image,
        )
        self._docker_build(
            instance_dockerfile, self.definition.output_image, platform=platform
        )
        return {
            "source_image": self.definition.source_image,
            "base_image": self.definition.base_image,
            "output_image": self.definition.output_image,
            "platform": platform,
            "base_dockerfile": str(base_dockerfile),
            "instance_dockerfile": str(instance_dockerfile),
            "build_log": str(self.log_path),
        }

    @observe_stage(
        "builder",
        "validate_instance",
        ignore_inputs=["self"],
        log_context=lambda self: (
            f"{self.definition.case.instance_id} using "
            f"{self.definition.output_image}"
        ),
    )
    def validate(self) -> dict[str, object]:
        reproduce = self.definition.case.case_dir / self.definition.case.reproduce_script
        f2p_scripts = [
            self.definition.case.case_dir / relative
            for relative in self.definition.case.fail_to_pass_scripts
        ]
        p2p_scripts = [
            self.definition.case.case_dir / relative
            for relative in self.definition.case.pass_to_pass_scripts
        ]
        reference_patch = (
            self.definition.case.case_dir / self.definition.case.reference_patch
        )
        container_name = (
            f"misconfigbench-build-{self.definition.case.instance_id.lower()}-"
            f"{uuid.uuid4().hex[:10]}"
        )
        try:
            self._run(
                self.definition.case.docker_create_command(
                    container_name,
                    image_name=self.definition.output_image,
                )
            )
            self._run(
                [
                    "docker",
                    "cp",
                    str(reproduce),
                    f"{container_name}:/tmp/misconfigbench-reproduce.sh",
                ]
            )
            for index, script in enumerate(f2p_scripts):
                self._run(
                    [
                        "docker",
                        "cp",
                        str(script),
                        f"{container_name}:/tmp/misconfigbench-f2p-{index}.sh",
                    ]
                )
            for index, script in enumerate(p2p_scripts):
                self._run(
                    [
                        "docker",
                        "cp",
                        str(script),
                        f"{container_name}:/tmp/misconfigbench-p2p-{index}.sh",
                    ]
                )
            self._run(["docker", "start", container_name])
            self._wait_until_ready(container_name)
            reproduction = self._run(
                [
                    "docker",
                    "exec",
                    container_name,
                    "bash",
                    "/tmp/misconfigbench-reproduce.sh",
                ],
                check=False,
            )
            pre_fix_f2p = [
                self._run(
                    [
                        "docker",
                        "exec",
                        container_name,
                        "bash",
                        f"/tmp/misconfigbench-f2p-{index}.sh",
                    ],
                    check=False,
                    timeout_seconds=180,
                )
                for index in range(len(f2p_scripts))
            ]
            pre_fix_p2p = [
                self._run(
                    [
                        "docker",
                        "exec",
                        container_name,
                        "bash",
                        f"/tmp/misconfigbench-p2p-{index}.sh",
                    ],
                    check=False,
                    timeout_seconds=180,
                )
                for index in range(len(p2p_scripts))
            ]
        finally:
            self._run(["docker", "rm", "-f", container_name], check=False)

        evaluation = self._run(
            [
                str(self.definition.case.evaluator),
                str(reference_patch),
                self.definition.output_image,
            ],
            check=False,
            timeout_seconds=180,
        )
        reproduction_infrastructure_error = (
            "command not found" in reproduction.stderr.lower()
        )
        f2p_failed_before_fix = all(
            completed.returncode != 0 for completed in pre_fix_f2p
        )
        p2p_passed_before_fix = all(
            completed.returncode == 0 for completed in pre_fix_p2p
        )
        return {
            "reproduction": _completed_result(reproduction),
            "pre_fix_f2p": [
                _completed_result(completed) for completed in pre_fix_f2p
            ],
            "pre_fix_p2p": [
                _completed_result(completed) for completed in pre_fix_p2p
            ],
            "reference_evaluation": _completed_result(evaluation),
            "reproduction_infrastructure_error": (
                reproduction_infrastructure_error
            ),
            "success": (
                reproduction.returncode == 0
                and not reproduction_infrastructure_error
                and f2p_failed_before_fix
                and p2p_passed_before_fix
                and evaluation.returncode == 0
            ),
        }

    @observe_stage(
        "builder",
        "save_image_archive",
        ignore_inputs=["self"],
        output_formatter=str,
        log_context=lambda self: (
            f"{self.definition.output_image} -> {self.definition.archive}"
        ),
    )
    def save_archive(self) -> Path:
        self.definition.archive.parent.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.NamedTemporaryFile(
            prefix=f".{self.definition.archive.name}.",
            suffix=".tmp",
            dir=self.definition.archive.parent,
            delete=False,
        )
        temporary_path = Path(temporary.name)
        temporary.close()
        try:
            with temporary_path.open("wb") as raw_output:
                with gzip.GzipFile(fileobj=raw_output, mode="wb", compresslevel=6) as output:
                    process = subprocess.Popen(
                        ["docker", "save", self.definition.output_image],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    )
                    assert process.stdout is not None
                    while chunk := process.stdout.read(1024 * 1024):
                        output.write(chunk)
                    stderr = process.stderr.read() if process.stderr else b""
                    return_code = process.wait()
            if return_code != 0:
                raise RuntimeErrorWithOutput(
                    f"docker save failed: {stderr.decode(errors='replace')}"
                )
            os.replace(temporary_path, self.definition.archive)
        finally:
            if temporary_path.exists():
                temporary_path.unlink()
        return self.definition.archive

    def _ensure_source_image(self) -> None:
        inspected = self._run(
            ["docker", "image", "inspect", self.definition.source_image],
            check=False,
        )
        if inspected.returncode == 0:
            return
        pulled = self._run(
            ["docker", "pull", self.definition.source_image],
            check=False,
            timeout_seconds=600,
        )
        if pulled.returncode != 0:
            raise FileNotFoundError(
                f"Source image is unavailable locally and could not be pulled: "
                f"{self.definition.source_image}\n{pulled.stderr}"
            )

    def _render_dockerfile(
        self,
        template_path: Path,
        destination: Path,
        context: dict[str, str],
    ) -> Path:
        rendered = render_template(
            template_path.read_text(encoding="utf-8"),
            context,
        )
        destination.write_text(rendered, encoding="utf-8")
        return destination

    def _source_platform(self) -> str:
        completed = self._run(
            [
                "docker",
                "image",
                "inspect",
                "--format",
                "{{.Os}}/{{.Architecture}}",
                self.definition.source_image,
            ]
        )
        platform = completed.stdout.strip()
        if not platform or "/" not in platform:
            raise RuntimeErrorWithOutput(
                f"Could not determine platform for {self.definition.source_image}"
            )
        return platform

    def _docker_build(
        self,
        dockerfile: Path,
        tag: str,
        *,
        platform: str,
    ) -> None:
        command = [
            "docker",
            "build",
            "--progress=plain",
            "--platform",
            platform,
            "--tag",
            tag,
            "--file",
            str(dockerfile),
        ]
        if self.no_cache:
            command.append("--no-cache")
        command.append(str(self.definition.context_dir))
        with self.log_path.open("a", encoding="utf-8") as log:
            log.write(f"$ {shlex.join(command)}\n")
            log.flush()
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
            assert process.stdout is not None
            selector = selectors.DefaultSelector()
            selector.register(process.stdout, selectors.EVENT_READ)
            started_at = time.monotonic()
            next_progress = started_at + 30
            line_count = 0
            latest_line = "waiting for Docker output"
            timed_out = False
            try:
                while process.poll() is None:
                    now = time.monotonic()
                    if now - started_at >= 600:
                        timed_out = True
                        process.terminate()
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()
                        break
                    for key, _ in selector.select(timeout=1):
                        line = key.fileobj.readline()
                        if not line:
                            continue
                        log.write(line)
                        log.flush()
                        line_count += 1
                        latest_line = line.strip() or latest_line
                    if now >= next_progress:
                        logger.info(
                            "Docker build %s still running (%.0fs, %d output "
                            "lines); latest: %s",
                            tag,
                            now - started_at,
                            line_count,
                            latest_line[:200],
                        )
                        next_progress = now + 30
                remaining = process.stdout.read()
                if remaining:
                    log.write(remaining)
                    log.flush()
                    remaining_lines = remaining.splitlines()
                    line_count += len(remaining_lines)
                    if remaining_lines:
                        latest_line = remaining_lines[-1]
            finally:
                selector.close()
                process.stdout.close()
            log.write("\n")
        if timed_out:
            raise RuntimeErrorWithOutput(
                f"Docker build timed out after 600 seconds for {tag}; "
                f"last output: {latest_line[:200]}; see {self.log_path}"
            )
        if process.returncode != 0:
            raise RuntimeErrorWithOutput(
                f"Docker build failed for {tag} with exit code "
                f"{process.returncode}; last output: {latest_line[:200]}; "
                f"see {self.log_path}"
            )

    def _wait_until_ready(self, container_name: str) -> None:
        deadline = time.monotonic() + self.definition.case.ready_timeout_seconds
        while time.monotonic() < deadline:
            running = self._run(
                [
                    "docker",
                    "inspect",
                    "--format",
                    "{{.State.Running}}",
                    container_name,
                ],
                check=False,
            )
            if running.stdout.strip() != "true":
                break
            ready = self._run(
                [
                    "docker",
                    "exec",
                    container_name,
                    "bash",
                    "-lc",
                    self.definition.case.ready_check,
                ],
                check=False,
            )
            if ready.returncode == 0:
                return
            time.sleep(1)
        logs = self._run(["docker", "logs", container_name], check=False)
        raise RuntimeErrorWithOutput(
            "Built container did not become ready.\n" + logs.stdout + logs.stderr
        )

    @staticmethod
    def _run(
        command: list[str],
        *,
        check: bool = True,
        timeout_seconds: int = 30,
    ) -> subprocess.CompletedProcess[str]:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            timeout=timeout_seconds,
        )
        if check and completed.returncode != 0:
            raise RuntimeErrorWithOutput(
                f"Command failed: {shlex.join(command)}\n"
                f"{completed.stdout}{completed.stderr}"
            )
        return completed


def _completed_result(
    completed: subprocess.CompletedProcess[str],
) -> dict[str, object]:
    return {
        "exit_code": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }


def _contained_path(root: Path, relative_path: str) -> Path:
    normalized = PurePosixPath(relative_path)
    if normalized.is_absolute() or ".." in normalized.parts:
        raise ValueError(f"Builder path must stay inside its root: {relative_path}")
    resolved_root = root.resolve()
    path = (resolved_root / normalized.as_posix()).resolve()
    if path != resolved_root and resolved_root not in path.parents:
        raise ValueError(f"Builder path escapes its root: {relative_path}")
    return path


def _optional_contained_path(root: Path, relative_path: str | None) -> Path | None:
    if not relative_path:
        return None
    return _contained_path(root, relative_path)
