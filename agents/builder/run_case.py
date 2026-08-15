from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from agents.builder.prompts import render_builder_prompt, resolve_prompt_template
from agents.manager import (
    DEFAULT_SUBSCRIPTION_MODEL,
    CaseDefinition,
    DockerInstanceBuilder,
    InstanceBuildDefinition,
    OpenHandsConfig,
    RegistryConfig,
    RuntimeErrorWithOutput,
    TAXONOMY_PATH,
    create_run_dir,
    load_case_documents,
    load_repository_env,
    login_registry,
    observe_stage,
    push_registry_image,
    record_image_distribution,
    run_openhands_agent,
)


REPO_ROOT = Path(__file__).resolve().parents[2]
BENCHMARK_CASE_IMAGE = re.compile(
    r"^(?:ca|cb|cc|cd)\d+:",
    re.IGNORECASE,
)
GENERATED_FILES = (
    "instance.json",
    "meta/metadata.json",
    "meta/gold_patch.diff",
    "build/build.json",
    "build/requirements.md",
    "harness/repro.sh",
    "harness/f2p.sh",
    "harness/p2p.sh",
    "harness/eval_patch.sh",
)


def main(argv: list[str] | None = None) -> int:
    load_repository_env(REPO_ROOT)
    args = _parse_args(argv)
    canonical_case_dir = REPO_ROOT / "instances" / args.instance_id
    description_path = canonical_case_dir / "meta" / "description.md"
    if not description_path.is_file():
        print(f"Missing builder input: {description_path}", file=sys.stderr)
        return 2

    run_dir = create_run_dir(REPO_ROOT, f"builder-{args.instance_id}", args.run_dir)
    run_dir.mkdir(parents=True, exist_ok=False)
    workspace_root = run_dir / "instance_workspace"
    shutil.copytree(
        canonical_case_dir,
        workspace_root,
        ignore=shutil.ignore_patterns(
            "image", "workspace", "__pycache__", ".DS_Store"
        ),
    )
    needs_generation = args.regenerate or not _is_complete(workspace_root)

    result: dict[str, object] = {
        "instance_id": args.instance_id,
        "run_dir": str(run_dir),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "agent": args.agent,
        "agent_role": "builder",
        "input": str(description_path),
        "generation_required": needs_generation,
        "prompt_template": str(resolve_prompt_template(REPO_ROOT)),
        "success": False,
    }
    try:
        task_prompt = render_builder_prompt(
            REPO_ROOT,
            args.instance_id,
            description_path.read_text(encoding="utf-8"),
            TAXONOMY_PATH.read_text(encoding="utf-8"),
            _docker_image_inventory(args.instance_id),
        )
        task_prompt_path = run_dir / "task_prompt.md"
        task_prompt_path.write_text(task_prompt, encoding="utf-8")
        result["task_prompt"] = str(task_prompt_path)

        if needs_generation:
            if args.agent != "openhands":
                raise ValueError(
                    "This instance only has a description. Generate its files with "
                    "--agent openhands (normally together with --subscription-login)."
                )
            agent_response = _run_openhands_builder(
                task_prompt,
                workspace_root,
                run_dir,
                _openhands_config(args),
                args.instance_id,
                "initial generation",
            )
            result["agent_response"] = agent_response
            result["agent_attempts"] = [
                {"attempt": 1, "response": agent_response}
            ]

        build_attempts = (
            max(1, args.max_build_attempts)
            if needs_generation and args.agent == "openhands"
            else 1
        )
        result["build_attempts"] = []
        builder: DockerInstanceBuilder | None = None
        for attempt in range(1, build_attempts + 1):
            attempt_result: dict[str, object] = {"attempt": attempt}
            result["build_attempts"].append(attempt_result)
            try:
                _ensure_layer_directories(workspace_root)
                _validate_generated_contract(workspace_root)
                load_case_documents(
                    workspace_root, expected_instance_id=args.instance_id
                )
                _make_harness_executable(workspace_root)
                case = CaseDefinition.load(workspace_root, repo_root=REPO_ROOT)
                definition = InstanceBuildDefinition.load(case)
                builder = DockerInstanceBuilder(
                    definition,
                    run_dir,
                    no_cache=args.no_cache,
                )

                if args.dry_run:
                    result["dry_run"] = True
                    result["instance_workspace"] = str(workspace_root)
                    result["success"] = True
                    return 0

                result["build"] = builder.build()
                validation = builder.validate()
                result["validation"] = validation
                if not validation["success"]:
                    raise RuntimeErrorWithOutput(
                        "Generated instance failed host validation:\n"
                        + json.dumps(validation, indent=2, ensure_ascii=True)
                    )
                attempt_result["success"] = True
                break
            except Exception as exc:  # noqa: BLE001
                attempt_result["success"] = False
                attempt_result["error"] = f"{type(exc).__name__}: {exc}"
                if attempt >= build_attempts:
                    raise

                correction_dir = run_dir / f"correction-{attempt + 1}"
                correction_dir.mkdir(parents=True, exist_ok=False)
                correction_prompt = _render_correction_prompt(
                    task_prompt,
                    exc,
                    run_dir / "docker_build.log",
                )
                correction_prompt_path = (
                    correction_dir / "task_prompt.md"
                )
                correction_prompt_path.write_text(
                    correction_prompt,
                    encoding="utf-8",
                )
                response = _run_openhands_builder(
                    correction_prompt,
                    workspace_root,
                    correction_dir,
                    _openhands_config(args),
                    args.instance_id,
                    f"host correction {attempt + 1}/{build_attempts}",
                )
                result["agent_response"] = response
                result.setdefault("agent_attempts", []).append(
                    {
                        "attempt": attempt + 1,
                        "prompt": str(correction_prompt_path),
                        "response": response,
                    }
                )

        if builder is None:
            raise RuntimeError("Builder did not produce a buildable instance")

        if not args.no_save_archive:
            result["image_archive"] = str(builder.save_archive())
        if args.push_image:
            if not args.registry_namespace:
                raise ValueError(
                    "--push-image requires --registry-namespace or "
                    "MISCONFIGBENCH_IMAGE_NAMESPACE"
                )
            _login_if_configured(args.registry)
            distribution = push_registry_image(
                builder.definition.output_image,
                case.instance_id,
                case.benchmark_version,
                RegistryConfig(
                    registry=args.registry,
                    namespace=args.registry_namespace,
                    repository_prefix=args.repository_prefix,
                    tag=args.image_tag,
                ),
            )
            record_image_distribution(
                workspace_root / "instance.json",
                distribution,
            )
            result["image_distribution"] = distribution
        if not args.no_publish:
            _publish_workspace(workspace_root, canonical_case_dir)
            result["published_to"] = str(canonical_case_dir)

        result["success"] = True
        return 0
    except Exception as exc:  # noqa: BLE001
        result["error"] = f"{type(exc).__name__}: {exc}"
        return 1
    finally:
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
        (run_dir / "result.json").write_text(
            json.dumps(result, indent=2, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(result, indent=2, ensure_ascii=True))


def _is_complete(case_dir: Path) -> bool:
    return all((case_dir / relative).is_file() for relative in GENERATED_FILES)


def _ensure_layer_directories(case_dir: Path) -> None:
    context_dir = case_dir / "build" / "context"
    for layer in ("base-overlay", "fault-overlay"):
        (context_dir / layer).mkdir(parents=True, exist_ok=True)


def _validate_generated_contract(case_dir: Path) -> None:
    missing = [
        str(case_dir / relative)
        for relative in GENERATED_FILES
        if not (case_dir / relative).is_file()
    ]
    if missing:
        raise FileNotFoundError(
            "Builder did not produce the complete instance contract:\n"
            + "\n".join(missing)
        )
    build_context = case_dir / "build" / "context"
    for layer in ("base-overlay", "fault-overlay"):
        if not (build_context / layer).is_dir():
            raise FileNotFoundError(
                f"Builder output is missing build/context/{layer}"
            )
    gold_patch = case_dir / "meta/gold_patch.diff"
    parsed_patch = subprocess.run(
        ["git", "apply", "--numstat", str(gold_patch)],
        capture_output=True,
        text=True,
        check=False,
    )
    if parsed_patch.returncode != 0:
        raise ValueError(
            "Builder produced an invalid meta/gold_patch.diff: "
            + (parsed_patch.stderr or parsed_patch.stdout).strip()
        )


def _make_harness_executable(case_dir: Path) -> None:
    for script in (case_dir / "harness").glob("*.sh"):
        script.chmod(script.stat().st_mode | 0o111)
    for script in (case_dir / "build" / "context" / "scripts").glob("*.sh"):
        script.chmod(script.stat().st_mode | 0o111)


def _publish_workspace(workspace: Path, destination: Path) -> None:
    for child in workspace.iterdir():
        target = destination / child.name
        if child.name == "image":
            target.mkdir(parents=True, exist_ok=True)
            for archive in child.iterdir():
                shutil.copy2(archive, target / archive.name)
        elif child.is_dir():
            shutil.copytree(child, target, dirs_exist_ok=True)
        else:
            shutil.copy2(child, target)


def _docker_image_inventory(instance_id: str) -> str:
    completed = subprocess.run(
        [
            "docker",
            "images",
            "--format",
            "{{.Repository}}:{{.Tag}}",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        return "(Docker image inventory unavailable)"
    reserved_prefix = f"{instance_id.lower()}:"
    images = sorted(
        image
        for image in completed.stdout.splitlines()
        if (
            "<none>" not in image
            and not image.lower().startswith(reserved_prefix)
            and not BENCHMARK_CASE_IMAGE.match(image)
        )
    )
    return "\n".join(f"- {image}" for image in images) or "(No local images)"


def _render_correction_prompt(
    original_prompt: str,
    error: Exception,
    build_log_path: Path,
) -> str:
    build_log = ""
    if build_log_path.is_file():
        build_log = build_log_path.read_text(
            encoding="utf-8",
            errors="replace",
        )[-12000:]
    return (
        original_prompt
        + "\n\n## Host Validation Feedback\n\n"
        + "The host rejected the generated instance. Inspect the existing "
        + "workspace and correct its files in place. Do not merely explain the "
        + "error. Keep the original public problem and taxonomy family. Use an "
        + "independent clean source image appropriate for the target software.\n\n"
        + f"Error:\n```\n{type(error).__name__}: {error}\n```\n"
        + (f"\nDocker build log:\n```\n{build_log}\n```\n" if build_log else "")
    )


@observe_stage(
    "builder",
    "generate_instance",
    ignore_inputs=["task_prompt", "workspace_root", "run_dir", "config"],
    log_context=lambda task_prompt, workspace_root, run_dir, config, instance_id, phase: (
        f"{instance_id}, {phase}, model {config.model}"
    ),
)
def _run_openhands_builder(
    task_prompt: str,
    workspace_root: Path,
    run_dir: Path,
    config: OpenHandsConfig,
    instance_id: str,
    phase: str,
) -> str:
    os.environ.setdefault("OPENHANDS_SUPPRESS_BANNER", "1")
    from agents.builder.openhands_tools import register_builder_tools

    registered_tools = register_builder_tools(workspace_root)
    return run_openhands_agent(
        task_prompt,
        registered_tools,
        run_dir,
        config,
        workspace_dir=workspace_root,
    )


def _openhands_config(args: argparse.Namespace) -> OpenHandsConfig:
    return OpenHandsConfig(
        model=args.model,
        api_key=args.api_key,
        base_url=args.base_url,
        subscription_login=args.subscription_login,
        max_iterations=args.max_iterations,
        max_runtime_seconds=args.agent_timeout,
    )


def _login_if_configured(registry: str) -> None:
    username = os.getenv("DOCKERHUB_USERNAME", "")
    token = os.getenv("DOCKERHUB_TOKEN", "")
    if bool(username) != bool(token):
        raise ValueError(
            "DOCKERHUB_USERNAME and DOCKERHUB_TOKEN must be configured together"
        )
    if username and token:
        login_registry(registry, username, token)


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a benchmark instance from meta/description.md, then build "
            "and validate its Docker image."
        )
    )
    parser.add_argument("instance_id")
    parser.add_argument(
        "--agent",
        choices=["deterministic", "openhands"],
        default="deterministic",
        help="OpenHands is required when generated instance files do not exist.",
    )
    parser.add_argument("--regenerate", action="store_true")
    parser.add_argument(
        "--model",
        default=os.getenv("LLM_MODEL", DEFAULT_SUBSCRIPTION_MODEL),
    )
    parser.add_argument("--api-key", default=os.getenv("LLM_API_KEY"))
    parser.add_argument("--base-url", default=os.getenv("LLM_BASE_URL"))
    parser.add_argument("--subscription-login", action="store_true")
    parser.add_argument("--max-iterations", type=int, default=30)
    parser.add_argument(
        "--agent-timeout",
        type=int,
        default=int(
            os.getenv("MISCONFIGBENCH_AGENT_TIMEOUT_SECONDS", "900")
        ),
        help="Maximum wall-clock seconds for each OpenHands conversation.",
    )
    parser.add_argument("--max-build-attempts", type=int, default=3)
    parser.add_argument("--run-dir")
    parser.add_argument("--no-cache", action="store_true")
    parser.add_argument("--no-save-archive", action="store_true")
    parser.add_argument("--no-publish", action="store_true")
    parser.add_argument(
        "--push-image",
        action="store_true",
        help="Push the validated output image to a Docker registry.",
    )
    parser.add_argument(
        "--registry",
        default=os.getenv("MISCONFIGBENCH_DOCKER_REGISTRY", "docker.io"),
    )
    parser.add_argument(
        "--registry-namespace",
        default=(
            os.getenv("MISCONFIGBENCH_IMAGE_NAMESPACE")
            or os.getenv("DOCKERHUB_USERNAME")
        ),
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


#  "error": "ValueError: Model 'gpt-5.3-codex' is not supported for subscription access. Supported models: gpt-5.4, gpt-5.4-mini, gpt-5.5, gpt-5.6, gpt-5.6-luna, gpt-5.6-sol, gpt-5.6-terra"
if __name__ == "__main__":
    sys.exit(main())
