from __future__ import annotations

import argparse
import json
from pathlib import Path

from agents.evaluator.troubleshooter.scoring import aggregate_diagnosis_results
from agents.manager import TAXONOMY_PATH
from agents.evaluator.report import average_field, group_identity


REPO_ROOT = Path(__file__).resolve().parents[3]


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    source = Path(args.runs_dir).resolve()
    report = grouped_report(source)
    output = Path(args.output).resolve() if args.output else source / "diagnosis_report.json"
    output.write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=True))
    return 0


def grouped_report(runs_dir: Path) -> dict[str, object]:
    groups: dict[str, dict] = {}
    for path in sorted(runs_dir.rglob("diagnosis_result.json")):
        document = json.loads(path.read_text(encoding="utf-8"))
        identity = group_identity(document)
        key = json.dumps(identity, sort_keys=True)
        group = groups.setdefault(key, {"experiment": identity, "records": [], "runs": [], "evidence": []})
        group["runs"].append(str(path))
        if isinstance(document.get("evidence"), dict):
            group["evidence"].append(document["evidence"])
        result = document.get("result")
        if isinstance(result, dict):
            group["records"].append(result)
    reports = []
    for key in sorted(groups):
        group = groups[key]
        records = group["records"]
        reports.append({
            "experiment": group["experiment"],
            "total_runs": len(group["runs"]),
            "scored_runs": len(records),
            "unscored_runs": len(group["runs"]) - len(records),
            "unique_scored_cases": len({record.get("instance_id") for record in records}),
            "metrics": aggregate_diagnosis_results(records, TAXONOMY_PATH) if records else None,
            "result_files": group["runs"],
            "evidence": {field: average_field(group["evidence"], field) for field in (
                "sufficient_evidence_acquired", "citation_validity", "core_claim_support_rate")},
        })
    return {
        "schema_version": 2,
        "group_by": ["provider", "model", "mode", "max_iterations", "agent_timeout",
                     "protocol_version", "repair_context", "evidence_mode", "evidence_condition"],
        "counting_unit": "run",
        "groups": reports,
    }


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Aggregate deterministic MisconfigBench diagnosis metrics."
    )
    parser.add_argument("--runs-dir", default=str(REPO_ROOT / "runs"))
    parser.add_argument("--output")
    return parser.parse_args(argv)


if __name__ == "__main__":
    raise SystemExit(main())
