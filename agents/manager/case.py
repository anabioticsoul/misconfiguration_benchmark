"""Shared benchmark case loading and validation."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path, PurePosixPath

from agents.manager.validation import load_case_documents


@dataclass(frozen=True)
class CaseDefinition:
    case_dir: Path
    repo_root: Path
    instance_id: str
    benchmark_version: str
    task_type: str
    software_name: str
    software_version: str
    image_name: str
    image_archive: Path
    image_archive_format: str
    image_distribution: dict[str, str]
    ready_check: str
    ready_timeout_seconds: int
    runtime_entrypoint: str | None
    runtime_command: tuple[str, ...]
    public_problem: Path
    prompt_protocol: dict[str, str]
    builder_protocol: dict[str, str]
    evaluator: Path
    allowed_modified_files: tuple[str, ...]
    reproduce_script: str
    fail_to_pass_scripts: tuple[str, ...]
    pass_to_pass_scripts: tuple[str, ...]
    reference_patch: str

    @classmethod
    def load(
        cls,
        case_dir: Path,
        *,
        repo_root: Path | None = None,
    ) -> "CaseDefinition":
        case_dir = case_dir.resolve()
        repo_root = repo_root.resolve() if repo_root else case_dir.parents[1]
        instance, metadata = load_case_documents(case_dir)
        image = instance["image"]
        image_distribution = dict(image.get("distribution", {}))
        runtime = instance["runtime"]
        software = instance.get("software", {})
        prompt_protocol = dict(instance.get("prompt_protocol", {}))
        builder_protocol = dict(instance.get("builder_protocol", {}))
        allowed_files = tuple(
            _relative_container_path(path)
            for path in metadata["repair_policy"]["allowed_modified_files"]
        )
        if not allowed_files:
            raise ValueError("repair_policy.allowed_modified_files must not be empty")

        return cls(
            case_dir=case_dir,
            repo_root=repo_root,
            instance_id=instance["instance_id"],
            benchmark_version=str(instance.get("version", "")),
            task_type=instance.get("task_type", ""),
            software_name=software.get("name", ""),
            software_version=software.get("version", ""),
            image_name=image["name"],
            image_archive=case_dir / image["archive"],
            image_archive_format=image.get("archive_format", "docker_save_tar_gzip"),
            image_distribution=image_distribution,
            ready_check=runtime["ready_check"],
            ready_timeout_seconds=int(runtime["ready_timeout_seconds"]),
            runtime_entrypoint=runtime.get("entrypoint"),
            runtime_command=tuple(runtime.get("command", [])),
            public_problem=case_dir
            / instance["task_files"]["public_problem_statement"],
            prompt_protocol=prompt_protocol,
            builder_protocol=builder_protocol,
            evaluator=case_dir / instance["host_harness"]["evaluate_prediction"],
            allowed_modified_files=allowed_files,
            reproduce_script=instance["evaluator_harness"]["reproduce"],
            fail_to_pass_scripts=tuple(
                instance["task_files"]["fail_to_pass"]
            ),
            pass_to_pass_scripts=tuple(
                instance["task_files"]["pass_to_pass"]
            ),
            reference_patch=instance["task_files"]["reference_patch"],
        )

    def container_path(self, relative_path: str) -> str:
        return f"/{relative_path}"

    def read_public_problem(self) -> str:
        return self.public_problem.read_text(encoding="utf-8")

    def docker_create_command(
        self,
        container_name: str,
        *,
        image_name: str | None = None,
    ) -> list[str]:
        command = ["docker", "create", "--name", container_name]
        if self.runtime_entrypoint:
            command.extend(["--entrypoint", self.runtime_entrypoint])
        command.append(image_name or self.image_name)
        command.extend(self.runtime_command)
        return command

    def validate_files(self) -> None:
        required = [
            self.public_problem,
            self.evaluator,
        ]
        missing = [str(path) for path in required if not path.is_file()]
        if missing:
            raise FileNotFoundError("Missing case files:\n" + "\n".join(missing))
def _relative_container_path(path: str) -> str:
    if not path.startswith("/"):
        raise ValueError(f"Expected absolute container path, got: {path}")
    normalized = PurePosixPath(path)
    if ".." in normalized.parts:
        raise ValueError(f"Container path escapes root: {path}")
    return normalized.as_posix().lstrip("/")
