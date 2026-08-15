"""Public Hugging Face dataset export and upload."""

from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any

from agents.manager.observability import observe_stage
from agents.manager.validation import load_case_documents


@observe_stage(
    "publisher",
    "export_huggingface_dataset",
    ignore_inputs=["repo_root"],
    output_formatter=str,
    log_context=lambda repo_root, output_dir: str(output_dir),
)
def export_public_dataset(repo_root: Path, output_dir: Path) -> Path:
    """Export public case data without private oracle or evaluator artifacts."""
    output_dir.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, Any]] = []
    for case_dir in sorted((repo_root / "instances").iterdir()):
        if not (case_dir / "instance.json").is_file():
            continue
        manifest, _ = load_case_documents(case_dir)
        problem_path = (
            case_dir / manifest["task_files"]["public_problem_statement"]
        )
        image = manifest["image"]
        public_image: dict[str, Any] = {"name": image["name"]}
        if image.get("distribution"):
            public_image["distribution"] = image["distribution"]
        records.append(
            {
                "instance_id": manifest["instance_id"],
                "benchmark": manifest.get("benchmark", "MisconfigBench"),
                "version": manifest.get("version", ""),
                "task_type": manifest["task_type"],
                "software": manifest.get("software", {}),
                "source": manifest.get("source", {}),
                "image": public_image,
                "problem_statement": problem_path.read_text(encoding="utf-8"),
            }
        )

    dataset_path = output_dir / "data.jsonl"
    dataset_path.write_text(
        "".join(
            json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n"
            for record in records
        ),
        encoding="utf-8",
    )
    shutil.copy2(repo_root / "standards/taxonomy.json", output_dir / "taxonomy.json")
    (output_dir / "README.md").write_text(
        _dataset_card(len(records)),
        encoding="utf-8",
    )
    return dataset_path


@observe_stage(
    "publisher",
    "upload_huggingface_dataset",
    ignore_inputs=["token"],
    log_context=lambda output_dir, repo_id, token, private: (
        f"{output_dir} -> {repo_id}"
    ),
)
def upload_public_dataset(
    output_dir: Path,
    repo_id: str,
    token: str,
    *,
    private: bool = False,
) -> str:
    if not token:
        raise ValueError("HF_TOKEN is required for Hugging Face upload")
    try:
        from huggingface_hub import HfApi
    except ImportError as exc:
        raise RuntimeError(
            "Install huggingface-hub before using --upload"
        ) from exc

    api = HfApi(token=token)
    repo_url = api.create_repo(
        repo_id=repo_id,
        repo_type="dataset",
        private=private,
        exist_ok=True,
    )
    api.upload_folder(
        repo_id=repo_id,
        repo_type="dataset",
        folder_path=str(output_dir),
        commit_message="Publish MisconfigBench public dataset",
    )
    return str(repo_url)


def validate_image_distributions(dataset_path: Path) -> None:
    """Require immutable image references before publishing a public dataset."""
    missing: list[str] = []
    for line in dataset_path.read_text(encoding="utf-8").splitlines():
        record = json.loads(line)
        distribution = record.get("image", {}).get("distribution", {})
        if not distribution.get("pull_reference"):
            missing.append(str(record.get("instance_id", "<unknown>")))
    if missing:
        raise ValueError(
            "Publish Docker images before uploading the dataset; missing image "
            f"distribution for: {', '.join(missing)}"
        )


def _dataset_card(instance_count: int) -> str:
    return f"""---
license: apache-2.0
task_categories:
- text-generation
language:
- en
pretty_name: MisconfigBench
---

# MisconfigBench

Public task records for {instance_count} validated misconfiguration instances.
Private oracle metadata, reference patches, and evaluator harnesses are not
included. Container images are distributed separately through the registry
references recorded in each instance.
"""


__all__ = [
    "export_public_dataset",
    "upload_public_dataset",
    "validate_image_distributions",
]
