from __future__ import annotations

import difflib
import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CaseDefinition:
    case_dir: Path
    instance_id: str
    image_name: str
    image_archive: Path
    image_import_changes: tuple[str, ...]
    ready_check: str
    ready_timeout_seconds: int
    public_problem: Path
    evaluator: Path
    allowed_modified_files: tuple[str, ...]

    @classmethod
    def load(cls, case_dir: Path) -> "CaseDefinition":
        case_dir = case_dir.resolve()
        instance = _read_json(case_dir / "instance.json")
        metadata = _read_json(case_dir / instance["task_files"]["private_metadata"])
        image = instance["image"]
        runtime = instance["runtime"]
        allowed_files = tuple(
            _relative_container_path(path)
            for path in metadata["repair_policy"]["allowed_modified_files"]
        )
        if not allowed_files:
            raise ValueError("repair_policy.allowed_modified_files must not be empty")

        return cls(
            case_dir=case_dir,
            instance_id=instance["instance_id"],
            image_name=image["name"],
            image_archive=case_dir / image["archive"],
            image_import_changes=tuple(image["import_changes"]),
            ready_check=runtime["ready_check"],
            ready_timeout_seconds=int(runtime["ready_timeout_seconds"]),
            public_problem=case_dir
            / instance["task_files"]["public_problem_statement"],
            evaluator=case_dir
            / instance["host_harness"]["evaluate_prediction"],
            allowed_modified_files=allowed_files,
        )

    def baseline_path(self, relative_path: str) -> Path:
        return self.case_dir / "workspace" / relative_path

    def container_path(self, relative_path: str) -> str:
        return f"/{relative_path}"

    def read_public_problem(self) -> str:
        return self.public_problem.read_text(encoding="utf-8")

    def validate_files(self) -> None:
        required = [
            self.image_archive,
            self.public_problem,
            self.evaluator,
            *[self.baseline_path(path) for path in self.allowed_modified_files],
        ]
        missing = [str(path) for path in required if not path.is_file()]
        if missing:
            raise FileNotFoundError("Missing case files:\n" + "\n".join(missing))


def build_prediction_patch(
    case: CaseDefinition,
    exported_files: dict[str, Path],
) -> str:
    chunks: list[str] = []
    for relative_path in case.allowed_modified_files:
        baseline = case.baseline_path(relative_path).read_text(encoding="utf-8")
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


def _read_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def _relative_container_path(path: str) -> str:
    if not path.startswith("/"):
        raise ValueError(f"Expected absolute container path, got: {path}")
    normalized = Path(path).as_posix().lstrip("/")
    if normalized.startswith("../") or normalized == "..":
        raise ValueError(f"Container path escapes root: {path}")
    return normalized

