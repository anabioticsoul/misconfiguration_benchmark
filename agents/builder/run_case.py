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
    CaseDefinition,
    DockerInstanceBuilder,
    DEFAULT_LLM_PROVIDER,
    InstanceBuildDefinition,
    OpenHandsConfig,
    RegistryConfig,
    RuntimeErrorWithOutput,
    TAXONOMY_PATH,
    create_run_dir,
    capture_agent_exception,
    configure_agent_failure_context,
    load_case_documents,
    load_repository_env,
    login_registry,
    observe_stage,
    push_registry_image,
    record_image_distribution,
    run_agent_entrypoint,
    run_openhands_agent,
    summarize_agent_usage,
)
from agents.manager.paths import instance_dir
from openhands.sdk.logger import get_logger


REPO_ROOT = Path(__file__).resolve().parents[2]
ASSETS_ROOT = REPO_ROOT / "assets"
BENCHMARK_CASE_IMAGE = re.compile(
    r"^(?:ca|cb|cc|cd)\d+:",
    re.IGNORECASE,
)
CASE_ID_PATTERN = re.compile(r"^(CA|CB|CC|CD)\d+$", re.IGNORECASE)
INELIGIBLE_RESPONSE = re.compile(
    r"(?im)^MISCONFIGBENCH_INELIGIBLE:\s*(?P<reason>.+)$"
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

logger = get_logger(__name__)


def main(argv: list[str] | None = None) -> int:
    load_repository_env(REPO_ROOT)
    args = _parse_args(argv)
    if args.validate_only:
        from agents.builder.validate_case import main as validate_case
        if args.regenerate or args.dry_run or args.push_image:
            raise ValueError("--validate-only cannot regenerate, dry-run, or push images")
        validation_args = [args.instance_id, "--timeout", str(args.validation_timeout)]
        if args.run_dir:
            validation_args.extend(["--run-dir", args.run_dir])
        return validate_case(validation_args)
    configure_agent_failure_context(instance_id=args.instance_id)
    canonical_case_dir = instance_dir(REPO_ROOT, args.instance_id)
    try:
        description_path = _sync_description_from_assets(
            args.instance_id,
            canonical_case_dir,
        )
    except (FileNotFoundError, ValueError) as exc:
        print(f"Missing builder input: {exc}", file=sys.stderr)
        return 2

    run_dir = create_run_dir(REPO_ROOT, f"builder-{args.instance_id}", args.run_dir)
    run_dir.mkdir(parents=True, exist_ok=False)
    configure_agent_failure_context(
        instance_id=args.instance_id,
        run_dir=run_dir,
    )
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
            if _record_ineligible_result(result, agent_response):
                return 0

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
                _preflight_generated_workspace(workspace_root)
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
                validation = builder.validate(timeout_seconds=args.validation_timeout)
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
                if _record_ineligible_result(result, response):
                    return 0

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
        capture_agent_exception(exc)
        return 1
    finally:
        result["agent_usage"] = summarize_agent_usage(run_dir)
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
        (run_dir / "result.json").write_text(
            json.dumps(result, indent=2, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(result, indent=2, ensure_ascii=True))


def _is_complete(case_dir: Path) -> bool:
    return all((case_dir / relative).is_file() for relative in GENERATED_FILES)


def _record_ineligible_result(result: dict[str, object], response: str) -> bool:
    """Turn an explicit source-fidelity rejection into a completed run."""
    match = INELIGIBLE_RESPONSE.search(response)
    if match is None:
        return False
    result["outcome"] = "ineligible"
    result["ineligible_reason"] = match.group("reason").strip()
    result["success"] = True
    return True


def _sync_description_from_assets(
    instance_id: str,
    case_dir: Path,
    assets_root: Path = ASSETS_ROOT,
) -> Path:
    """Initialize a missing instance description from its numbered asset."""
    match = CASE_ID_PATTERN.fullmatch(instance_id)
    if match is None:
        raise ValueError(
            f"Invalid instance ID {instance_id!r}; expected CA, CB, CC, or CD "
            "followed by a number"
        )

    normalized_id = instance_id.upper()
    source = assets_root / match.group(1).upper() / f"{normalized_id}.md"
    destination = case_dir / "meta" / "description.md"
    if destination.is_file():
        logger.info("Using existing builder description: %s", destination)
        return destination

    if source.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        logger.info(
            "Initialized builder description: %s -> %s", source, destination
        )
        return destination

    raise FileNotFoundError(
        f"expected {source} because {destination} does not exist"
    )


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


def _preflight_generated_workspace(case_dir: Path) -> None:
    """Reject shell patterns that turn ordinary agent mistakes into opaque runs."""
    scripts = sorted(
        {
            *(case_dir / "harness").glob("*.sh"),
            *(case_dir / "build" / "context" / "scripts").glob("*.sh"),
        }
    )
    failures: list[str] = []
    for script in scripts:
        parsed = subprocess.run(
            ["bash", "-n", str(script)],
            capture_output=True,
            text=True,
            check=False,
        )
        if parsed.returncode != 0:
            failures.append(
                f"{script.relative_to(case_dir)}: "
                f"{(parsed.stderr or parsed.stdout).strip()}"
            )
            continue

        contents = script.read_text(encoding="utf-8")
        relative_script = script.relative_to(case_dir)
        for number, line in enumerate(contents.splitlines(), start=1):
            streamed_shell = re.search(
                r"\bdocker\s+exec\s+(.*?)\b(?:bash|sh)\s+-s\b[^\n]*<", line
            )
            if streamed_shell and not re.search(
                r"(?:^|\s)(?:--interactive|-[it]*i[it]*)(?:\s|$)",
                streamed_shell.group(1),
            ):
                failures.append(
                    f"{relative_script}:{number}: docker exec requires -i when "
                    "streaming a shell script through stdin; otherwise tests may not run"
                )
        if (
            "git commit -qm baseline" in contents
            and re.search(r"\bgit(?:\s+-C\s+\S+)?\s+diff\s+--name-only\s+baseline\b", contents)
        ):
            failures.append(
                f"{relative_script}: `baseline` is a commit message, not a Git revision; "
                "use `git diff --name-only` after applying the patch"
            )
        if relative_script == Path("harness/eval_patch.sh") and re.search(
            r"<\s*harness/", contents
        ):
            failures.append(
                f"{relative_script}: evaluator must not read harness files through "
                "a relative host path; resolve its own script directory"
            )
        if "pipefail" not in contents:
            continue
        for number, line in enumerate(contents.splitlines(), start=1):
            if "|" not in line:
                continue
            has_early_awk_exit = bool(
                re.search(r"\|\s*awk\b.*\bexit\b", line)
            )
            has_quiet_grep = bool(
                re.search(r"\|\s*grep\b[^|]*-[A-Za-z]*q", line)
            )
            if has_early_awk_exit or has_quiet_grep:
                failures.append(
                    f"{script.relative_to(case_dir)}:{number}: "
                    "an early-exiting pipeline consumer is unsafe with pipefail; "
                    "capture the producer output first or use a direct command"
                )

    if failures:
        raise ValueError("Generated shell preflight failed:\n" + "\n".join(failures))


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
        + "Before finishing, run `bash -n` on every generated shell script. With "
        + "`set -o pipefail`, never pipe a long-running producer into `grep -q` "
        + "or `awk ... exit`: those consumers close the pipe early and can turn "
        + "a correct producer into SIGPIPE/exit 141 or 255. Prefer a direct "
        + "software query, capture output to a file, or consume the full stream. "
        + "Evaluator scripts must keep services alive through every F2P and P2P "
        + "check, and service harnesses must wait for their expected readiness "
        + "state rather than treating the first connection response as ready.\n\n"
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
    return OpenHandsConfig.from_environment(
        model=args.model,
        provider=args.llm_provider,
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
    parser.add_argument("--validate-only", action="store_true", help="Validate an existing image without rebuilding.")
    parser.add_argument("--validation-timeout", type=int, default=180)
    parser.add_argument(
        "--model",
        default=None,
    )
    parser.add_argument(
        "--llm-provider",
        choices=["openai_subscription", "openlux"],
        default=os.getenv("MISCONFIGBENCH_LLM_PROVIDER", DEFAULT_LLM_PROVIDER),
    )
    parser.add_argument("--api-key")
    parser.add_argument("--base-url")
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


#  "error": "ValueError: Model
# 'gpt-5.3-codex' is not supported for subscription access. Supported models: gpt-5.4, gpt-5.4-mini, gpt-5.5, gpt-5.6, gpt-5.6-luna, gpt-5.6-sol, gpt-5.6-terra"
if __name__ == "__main__":
    sys.exit(run_agent_entrypoint("builder", main))
3
