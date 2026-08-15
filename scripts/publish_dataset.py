from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from agents.manager.dataset import (
    export_public_dataset,
    upload_public_dataset,
    validate_image_distributions,
)
from agents.manager.settings import load_repository_env


REPO_ROOT = Path(__file__).resolve().parents[1]


def main(argv: list[str] | None = None) -> int:
    load_repository_env(REPO_ROOT)
    args = _parse_args(argv)
    output_dir = Path(args.output_dir).resolve()
    dataset_path = export_public_dataset(REPO_ROOT, output_dir)
    result: dict[str, object] = {
        "dataset": str(dataset_path),
        "output_dir": str(output_dir),
        "uploaded": False,
    }
    if args.upload:
        validate_image_distributions(dataset_path)
        if not args.repo_id:
            raise ValueError(
                "--upload requires --repo-id or MISCONFIGBENCH_HF_REPO"
            )
        result["repository"] = upload_public_dataset(
            output_dir,
            args.repo_id,
            os.getenv("HF_TOKEN", ""),
            private=args.private,
        )
        result["uploaded"] = True
    print(json.dumps(result, indent=2, ensure_ascii=True))
    return 0


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export and optionally upload the public MisconfigBench dataset."
    )
    parser.add_argument(
        "--output-dir",
        default=str(REPO_ROOT / "dist/huggingface"),
    )
    parser.add_argument(
        "--repo-id",
        default=os.getenv("MISCONFIGBENCH_HF_REPO"),
    )
    parser.add_argument("--upload", action="store_true")
    parser.add_argument("--private", action="store_true")
    return parser.parse_args(argv)


if __name__ == "__main__":
    raise SystemExit(main())
