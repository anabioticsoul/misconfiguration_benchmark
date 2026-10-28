"""Validation for the files shared by all benchmark roles."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


class ContractValidationError(ValueError):
    """Raised when an instance does not follow the benchmark contract."""


def load_case_documents(
    case_dir: Path,
    *,
    expected_instance_id: str | None = None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    manifest_path = case_dir / "instance.json"
    manifest = _read_json_object(manifest_path)
    _require_paths(
        manifest,
        manifest_path,
        (
            "instance_id",
            "task_type",
            "image.name",
            "image.archive",
            "runtime.ready_check",
            "runtime.ready_timeout_seconds",
            "task_files.public_problem_statement",
            "task_files.private_metadata",
            "task_files.reference_patch",
            "prompt_protocol.template",
            "builder_protocol.template",
            "builder_protocol.spec",
            "builder_protocol.requirements",
            "evaluator_harness.reproduce",
            "host_harness.evaluate_prediction",
            "patch_protocol.format",
        ),
    )
    instance_id = manifest["instance_id"]
    if expected_instance_id and instance_id != expected_instance_id:
        raise ContractValidationError(
            f"{manifest_path}: instance_id must be {expected_instance_id!r}, "
            f"got {instance_id!r}"
        )
    distribution = manifest["image"].get("distribution")
    if distribution is not None:
        if not isinstance(distribution, dict):
            raise ContractValidationError(
                f"{manifest_path}: image.distribution must be an object"
            )
        _require_paths(
            manifest,
            manifest_path,
            (
                "image.distribution.type",
                "image.distribution.reference",
                "image.distribution.digest",
                "image.distribution.pull_reference",
            ),
        )
        if distribution["type"] != "docker_registry":
            raise ContractValidationError(
                f"{manifest_path}: unsupported image distribution type "
                f"{distribution['type']!r}"
            )
        digest = distribution["digest"]
        if (
            not isinstance(digest, str)
            or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest)
        ):
            raise ContractValidationError(
                f"{manifest_path}: image.distribution.digest must be sha256"
            )

    metadata_path = case_dir / _string_at(
        manifest, "task_files.private_metadata", manifest_path
    )
    metadata = _read_json_object(metadata_path)
    _require_paths(
        metadata,
        metadata_path,
        (
            "instance_id",
            "private_oracle.classification.taxonomy_version",
            "private_oracle.classification.category_id",
            "private_oracle.faulty_targets",
            "repair_policy.allowed_modified_files",
            "repair_policy.forbidden_shortcuts",
            "observable_symptom",
            "oracle.fail_to_pass",
            "oracle.pass_to_pass",
        ),
    )
    if metadata["instance_id"] != instance_id:
        raise ContractValidationError(
            f"{metadata_path}: instance_id must match instance.json"
        )
    category_id = metadata["private_oracle"]["classification"]["category_id"]
    expected_category = instance_id[:2]
    if (
        not isinstance(category_id, str)
        or category_id.split("-", 1)[0] != expected_category
    ):
        raise ContractValidationError(
            f"{metadata_path}: classification.category_id must use the "
            f"{expected_category}- subtype family encoded by instance_id, "
            f"got {category_id!r}"
        )
    allowed_files = metadata["repair_policy"]["allowed_modified_files"]
    if not isinstance(allowed_files, list) or not allowed_files:
        raise ContractValidationError(
            f"{metadata_path}: repair_policy.allowed_modified_files "
            "must be a non-empty array"
        )
    diagnosis_oracle = metadata["private_oracle"].get("diagnosis_oracle")
    if diagnosis_oracle is not None:
        if not isinstance(diagnosis_oracle, dict):
            raise ContractValidationError(
                f"{metadata_path}: private_oracle.diagnosis_oracle must be an object"
            )
        component = diagnosis_oracle.get("component")
        if not isinstance(component, str) or not component.strip():
            raise ContractValidationError(
                f"{metadata_path}: private_oracle.diagnosis_oracle.component "
                "must be a non-empty string"
            )
    return manifest, metadata


def _read_json_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise ContractValidationError(f"Required contract file not found: {path}") from None
    except json.JSONDecodeError as exc:
        raise ContractValidationError(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ContractValidationError(f"{path}: root value must be an object")
    return value


def _require_paths(
    document: dict[str, Any],
    source: Path,
    paths: tuple[str, ...],
) -> None:
    missing = [path for path in paths if _lookup(document, path) is _MISSING]
    if missing:
        rendered = "\n".join(f"  - {path}" for path in missing)
        raise ContractValidationError(
            f"{source} does not follow the MisconfigBench contract. "
            f"Missing fields:\n{rendered}"
        )


def _string_at(document: dict[str, Any], path: str, source: Path) -> str:
    value = _lookup(document, path)
    if not isinstance(value, str) or not value:
        raise ContractValidationError(f"{source}: {path} must be a non-empty string")
    return value


def _lookup(document: dict[str, Any], path: str) -> Any:
    value: Any = document
    for part in path.split("."):
        if not isinstance(value, dict) or part not in value:
            return _MISSING
        value = value[part]
    return value


_MISSING = object()
