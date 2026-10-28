from __future__ import annotations

import argparse
import sys
from importlib import import_module
from pathlib import Path

from agents.manager import configure_agent_failure_context, load_repository_env, run_agent_entrypoint
from agents.manager.batch import run_case_batch
from agents.evaluator.output import evaluation_run_dir, experiment_identity
from agents.evaluator.oracles import repair_context
from agents.manager.case import CaseDefinition
from agents.manager.paths import instance_dir


REPO_ROOT = Path(__file__).resolve().parents[2]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Evaluate diagnosis or repair independently; use --task TASK --help for task options.",
        add_help=False,
        allow_abbrev=False,
    )
    parser.add_argument("--task", required=True, choices=["troubleshooter", "fixer"])
    parser.add_argument("--all", action="store_true", help="Verify and evaluate every complete instance.")
    parser.add_argument("--batch-dir", help="Override the batch output root (must not exist).")
    parser.add_argument("--verify-timeout", type=int, default=120)
    arguments = list(sys.argv[1:] if argv is None else argv)
    if not arguments or arguments in (["-h"], ["--help"]):
        parser.print_help()
        return 0
    args, remaining = parser.parse_known_args(arguments)

    if args.all:
        return run_agent_entrypoint(
            f"{args.task}-batch", lambda: _run_batch(args, remaining)
        )
    if args.batch_dir:
        parser.error("--batch-dir requires --all")

    if args.task == "troubleshooter":
        from agents.evaluator.troubleshooter.run_case import main as run_task
    else:
        from agents.evaluator.fixer.run_case import main as run_task

    return run_agent_entrypoint(args.task, lambda: run_task(remaining))


def _run_batch(args: argparse.Namespace, remaining: list[str]) -> int:
    from agents.builder.validate_case import main as verify_case

    load_repository_env(REPO_ROOT)
    task_module = import_module(f"agents.evaluator.{args.task}.run_case")
    # Reuse task parsing so model/provider options and defaults stay identical.
    task_args = task_module._parse_args(["CA1", *remaining])
    if task_args.run_dir or getattr(task_args, "diagnosis_file", None):
        raise ValueError("--all cannot use --run-dir or --diagnosis-file; use --batch-dir instead")
    if getattr(task_args, "agent", None) == "manual":
        raise ValueError("--all requires an automated agent, not a manual shell")
    if args.verify_timeout <= 0:
        raise ValueError("--verify-timeout must be positive")
    experiment = experiment_identity(task_module._openhands_config(task_args))
    replay = getattr(task_args, "evidence_mode", None) == "replay"
    if args.task == "fixer":
        experiment.update(protocol_version="rq2-v1", repair_context=task_args.repair_context)
    elif task_args.evidence_mode != "none":
        experiment.update(protocol_version="rq3-v1", evidence_mode=task_args.evidence_mode)
        if replay:
            if task_args.evidence_pack or not task_args.evidence_pack_dir:
                raise ValueError("Batch replay requires --evidence-pack-dir, not one shared pack")
            experiment["evidence_condition"] = task_args.evidence_condition
    if getattr(task_args, "evidence_review", None):
        raise ValueError("A human review cannot be shared across a batch")
    batch_dir = evaluation_run_dir(REPO_ROOT, args.task, "batch", experiment, args.batch_dir)
    configure_agent_failure_context(instance_id="batch", run_dir=batch_dir)

    def verify(case_id: str, destination: Path) -> int:
        return run_agent_entrypoint("builder_validation", lambda: verify_case([
            case_id, "--run-dir", str(destination), "--timeout", str(args.verify_timeout),
        ]))

    def evaluate(case_id: str, destination: Path) -> int:
        return run_agent_entrypoint(args.task, lambda: task_module.main([
            case_id, *remaining, "--run-dir", str(destination),
        ]))

    def eligibility(case_id: str) -> str | None:
        try:
            case = CaseDefinition.load(instance_dir(REPO_ROOT, case_id))
            if args.task == "fixer":
                repair_context(case, task_args.repair_context)
            elif replay:
                from agents.evaluator.troubleshooter.evidence_pack import load_pack
                load_pack(Path(task_args.evidence_pack_dir) / f"{case_id}.json", case_id, case)
        except (ValueError, OSError) as exc:
            return str(exc)
        return None

    return run_case_batch(
        REPO_ROOT, batch_dir, task=args.task, experiment=experiment,
        verify=None if replay else verify, evaluate=evaluate, eligibility=eligibility,
    )


if __name__ == "__main__":
    sys.exit(main())
