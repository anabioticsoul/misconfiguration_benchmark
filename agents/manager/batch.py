"""Discover complete instances and run verified cases sequentially."""

from __future__ import annotations

import json
import logging
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

from agents.manager.case import CaseDefinition


logger = logging.getLogger(__name__)
CaseRunner = Callable[[str, Path], int]


def discover_cases(repo_root: Path) -> tuple[list[str], list[dict[str, str]]]:
    candidates = []
    skipped = []
    for category in ("CA", "CB", "CC", "CD"):
        directories = [
            path for path in (repo_root / "instances" / category).glob("*")
            if path.is_dir() and re.fullmatch(rf"{category}\d+", path.name)
        ]
        for directory in sorted(directories, key=lambda path: int(path.name[2:])):
            try:
                case = CaseDefinition.load(directory, repo_root=repo_root)
                if case.instance_id != directory.name:
                    raise ValueError("Instance ID does not match its directory")
                case.validate_files()
                required = (
                    case.reproduce_script, case.reference_patch,
                    *case.fail_to_pass_scripts, *case.pass_to_pass_scripts,
                )
                for relative in required:
                    if not (directory / relative).is_file():
                        raise FileNotFoundError(f"Missing case file: {relative}")
                candidates.append(case.instance_id)
            except (OSError, ValueError, KeyError, TypeError) as exc:
                skipped.append({"instance_id": directory.name, "reason": str(exc)})
    return candidates, skipped


def run_case_batch(
    repo_root: Path,
    batch_dir: Path,
    *,
    task: str,
    experiment: dict[str, object],
    verify: CaseRunner | None,
    evaluate: CaseRunner,
    eligibility: Callable[[str], str | None] | None = None,
) -> int:
    batch_dir.mkdir(parents=True, exist_ok=False)
    candidates, skipped = discover_cases(repo_root)
    if eligibility:
        eligible = []
        for case_id in candidates:
            reason = eligibility(case_id)
            if reason:
                skipped.append({"instance_id": case_id, "reason": reason})
            else:
                eligible.append(case_id)
        candidates = eligible
    report = {
        "task": task,
        "experiment": experiment,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "status": "running",
        "skipped": skipped,
        "cases": [{"instance_id": case_id, "status": "pending"} for case_id in candidates],
    }

    def checkpoint() -> None:
        report["counts"] = dict(Counter(item["status"] for item in report["cases"]))
        temporary = batch_dir / "batch_result.json.tmp"
        temporary.write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
        temporary.replace(batch_dir / "batch_result.json")

    checkpoint()
    logger.info("Batch %s: %d complete cases, %d incomplete cases skipped; output %s",
                task, len(candidates), len(skipped), batch_dir)
    try:
        for index, item in enumerate(report["cases"], start=1):
            case_id = item["instance_id"]
            stage = "verification"
            try:
                stages = [("evaluation", evaluate, batch_dir / case_id)]
                if verify is not None:
                    stages.insert(0, ("verification", verify, batch_dir / "verification" / case_id))
                else:
                    item["verification_status"] = "not_required"
                for stage, runner, destination in stages:
                    item["status"] = stage
                    item[f"{stage}_dir"] = str(destination)
                    checkpoint()
                    logger.info("Batch [%d/%d] %s: %s", index, len(candidates), case_id, stage)
                    code = runner(case_id, destination)
                    item[f"{stage}_exit_code"] = code
                    if code != 0:
                        item["status"] = f"{stage}_failed"
                        break
                else:
                    item["status"] = "completed"
            except (Exception, SystemExit) as exc:
                item["status"] = f"{stage}_failed"
                item["error"] = f"{type(exc).__name__}: {exc}"
                logger.exception("Batch %s failed for %s; continuing", stage, case_id)
            finally:
                checkpoint()
        report["status"] = "finished"
    except KeyboardInterrupt:
        report["status"] = "interrupted"
        for item in report["cases"]:
            if item["status"] in {"verification", "evaluation"}:
                item["status"] = "interrupted"
        raise
    finally:
        report["finished_at"] = datetime.now(timezone.utc).isoformat()
        checkpoint()
        print(json.dumps(report, indent=2, ensure_ascii=True))
    return 0 if candidates and all(item["status"] == "completed" for item in report["cases"]) else 1
