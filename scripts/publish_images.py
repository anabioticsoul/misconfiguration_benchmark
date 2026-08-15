from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from agents.manager import (
    CaseDefinition,
    RegistryConfig,
    load_repository_env,
    login_registry,
    push_registry_image,
    record_image_distribution,
)


REPO_ROOT = Path(__file__).resolve().parents[1]


def main(argv: list[str] | None = None) -> int:
    load_repository_env(REPO_ROOT)
    args = _parse_args(argv)
    if not args.dry_run:
        _login_if_configured(args.registry)
    config = RegistryConfig(
        registry=args.registry,
        namespace=args.registry_namespace,
        repository_prefix=args.repository_prefix,
        tag=args.image_tag,
    )
    instance_ids = args.instance_ids or sorted(
        path.name
        for path in (REPO_ROOT / "instances").iterdir()
        if (path / "instance.json").is_file()
    )
    results: list[dict[str, object]] = []
    for instance_id in instance_ids:
        case = CaseDefinition.load(REPO_ROOT / "instances" / instance_id)
        reference = config.image_reference(
            case.instance_id,
            case.benchmark_version,
        )
        if args.dry_run:
            results.append(
                {
                    "instance_id": case.instance_id,
                    "local_image": case.image_name,
                    "reference": reference,
                    "pushed": False,
                }
            )
            continue
        distribution = push_registry_image(
            case.image_name,
            case.instance_id,
            case.benchmark_version,
            config,
        )
        record_image_distribution(
            case.case_dir / "instance.json",
            distribution,
        )
        results.append(
            {
                "instance_id": case.instance_id,
                "local_image": case.image_name,
                "distribution": distribution,
                "pushed": True,
            }
        )
    print(json.dumps({"images": results}, indent=2, ensure_ascii=True))
    return 0


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    namespace = (
        os.getenv("MISCONFIGBENCH_IMAGE_NAMESPACE")
        or os.getenv("DOCKERHUB_USERNAME")
    )
    parser = argparse.ArgumentParser(
        description="Push validated MisconfigBench images to a Docker registry."
    )
    parser.add_argument("instance_ids", nargs="*")
    parser.add_argument(
        "--registry",
        default=os.getenv("MISCONFIGBENCH_DOCKER_REGISTRY", "docker.io"),
    )
    parser.add_argument(
        "--registry-namespace",
        default=namespace,
        required=not namespace,
    )
    parser.add_argument(
        "--repository-prefix",
        default=os.getenv(
            "MISCONFIGBENCH_IMAGE_PREFIX",
            "misconfigbench",
        ),
    )
    parser.add_argument(
        "--image-tag",
        default=os.getenv("MISCONFIGBENCH_IMAGE_TAG"),
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def _login_if_configured(registry: str) -> None:
    username = os.getenv("DOCKERHUB_USERNAME", "")
    token = os.getenv("DOCKERHUB_TOKEN", "")
    if bool(username) != bool(token):
        raise ValueError(
            "DOCKERHUB_USERNAME and DOCKERHUB_TOKEN must be configured together"
        )
    if username and token:
        login_registry(registry, username, token)


if __name__ == "__main__":
    raise SystemExit(main())
