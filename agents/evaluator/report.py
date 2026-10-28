"""RQ2/RQ3 descriptive reports. No unpaired causal claims or inferred scores."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path


def group_identity(document: dict) -> dict:
    experiment = document.get("experiment") or {}
    identity = {"provider": experiment.get("provider", "unknown"),
                "model": experiment.get("model", "unknown"),
                "mode": experiment.get("mode", "live" if experiment else "unknown"),
                "max_iterations": experiment.get("max_iterations"),
                "agent_timeout": experiment.get("agent_timeout")}
    for field in ("protocol_version", "repair_context", "evidence_mode", "evidence_condition"):
        if field in experiment:
            identity[field] = experiment[field]
    return identity


def average_field(rows: list[dict], field: str) -> dict:
    values = [row[field] for row in rows if isinstance(row.get(field), (int, float, bool))]
    return {"measured_runs": len(values), "value": sum(values) / len(values) if values else None}


def grouped_repair_report(source: Path) -> dict:
    groups = {}
    for path in sorted(source.rglob("result.json")):
        record = json.loads(path.read_text())
        if record.get("agent_role") != "fixer":
            continue
        identity = group_identity(record)
        group = groups.setdefault(json.dumps(identity, sort_keys=True), {"experiment": identity, "rows": []})
        group["rows"].append(record)
    output = []
    for _, group in sorted(groups.items()):
        rows = group.pop("rows")
        eligible = [row for row in rows if row.get("status") != "skipped_missing_oracle"]
        evaluated = [row for row in eligible if isinstance(row.get("evaluation"), dict)]
        passed = sum(row.get("success") is True for row in evaluated)
        checks = [row["evaluation"].get("checks", {}) for row in evaluated]
        group.update(total_runs=len(rows), eligible_runs=len(eligible), evaluated_runs=len(evaluated),
                     execution_errors=len(eligible) - len(evaluated), passed=passed,
                     pass_rate_all_eligible=passed / len(eligible) if eligible else None,
                     pass_rate_evaluated=passed / len(evaluated) if evaluated else None,
                     checks={key: {"pass": sum(item.get(key) == "pass" for item in checks),
                                   "fail": sum(item.get(key) == "fail" for item in checks),
                                   "not_evaluated": sum(item.get(key, "not_evaluated") == "not_evaluated" for item in checks)}
                             for key in ("patch_apply", "policy", "f2p", "p2p", "safety")},
                     cases=[{"instance_id": row["instance_id"], "run_dir": row.get("run_dir"),
                             "success": row.get("success"), "error": row.get("error")} for row in rows])
        output.append(group)
    return {"schema_version": 1, "counting_unit": "run", "groups": output}


def paired_comparisons(source: Path) -> list[dict]:
    """Compare mean per-case outcomes only on matching, versioned inputs."""
    cohorts = {}
    for filename, role, field, baseline in (
        ("result.json", "fixer", "repair_context", "none"),
        ("diagnosis_result.json", "troubleshooter", "evidence_condition", "full"),
    ):
        for path in sorted(source.rglob(filename)):
            record = json.loads(path.read_text())
            if record.get("agent_role") != role or field not in record.get("experiment", {}):
                continue
            identity = group_identity(record)
            condition = identity.pop(field)
            provenance = record.get("provenance", {})
            hashes = provenance.get("case_files_sha256")
            if not hashes:
                continue
            if role == "fixer":
                if not isinstance(record.get("evaluation"), dict):
                    continue
                outcome = float(record.get("success") is True)
            else:
                if not isinstance(record.get("result"), dict) or not record.get("evidence_pack_sha256"):
                    continue
                outcome = float(bool(record["result"].get("joint", {}).get("joint_at_1")))
            key = json.dumps({"task": role, **identity}, sort_keys=True)
            cohort = cohorts.setdefault(key, {"identity": {"task": role, **identity},
                                               "baseline": baseline, "conditions": {}})
            # Different annotation/harness snapshots or evidence packs are not paired.
            case_key = json.dumps([record["instance_id"], hashes, provenance.get("image_reference"),
                                   record.get("evidence_pack_sha256")], sort_keys=True)
            runs = cohort["conditions"].setdefault(condition, defaultdict(list))
            runs[case_key].append(outcome)
    comparisons = []
    for _, cohort in sorted(cohorts.items()):
        baseline = cohort["conditions"].get(cohort["baseline"], {})
        for condition, runs in sorted(cohort["conditions"].items()):
            if condition == cohort["baseline"]:
                continue
            common = sorted(baseline.keys() & runs.keys())
            differences = [sum(runs[key]) / len(runs[key]) - sum(baseline[key]) / len(baseline[key]) for key in common]
            comparisons.append({"experiment": cohort["identity"], "baseline": cohort["baseline"],
                                "condition": condition, "paired_cases": len(common),
                                "condition_minus_baseline": sum(differences) / len(differences) if differences else None,
                                "baseline_only_cases": len(baseline.keys() - runs.keys()),
                                "condition_only_cases": len(runs.keys() - baseline.keys())})
    return comparisons


def main(argv=None) -> int:
    from agents.evaluator.troubleshooter.report import grouped_report
    parser = argparse.ArgumentParser(description="Summarize RQ2 repairs and RQ3 evidence by experimental condition.")
    parser.add_argument("--runs-dir", default="runs")
    parser.add_argument("--output")
    args = parser.parse_args(argv)
    source = Path(args.runs_dir).resolve()
    report = {"repair": grouped_repair_report(source), "diagnosis": grouped_report(source),
              "paired_comparisons": paired_comparisons(source),
              "comparison_note": "Descriptive condition-minus-baseline differences on matching scored cases; not causal attribution. No confidence intervals. Repeated runs are averaged within case."}
    destination = Path(args.output) if args.output else source / "evaluation_report.json"
    destination.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
