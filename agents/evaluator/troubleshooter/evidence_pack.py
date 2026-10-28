"""Prepare and project human-reviewed evidence packs without leaking labels."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from agents.evaluator.oracles import case_provenance, digest, reviewed
from agents.manager.case import CaseDefinition
from agents.manager.paths import instance_dir
from agents.evaluator.troubleshooter.evidence import load_observations, validate_observations


CONDITIONS = ("full", "description_only", "key_only", "key_removed", "matched_control")


def load_pack(path: Path, instance_id: str, case: CaseDefinition | None = None) -> dict:
    pack = json.loads(path.read_text())
    reviewed(pack, "evidence pack")
    if pack.get("instance_id") != instance_id or pack.get("schema_version") != 1:
        raise ValueError("Evidence pack case/schema mismatch")
    if case is not None and pack.get("case_sha256") != digest(case_provenance(case, "")["case_files_sha256"]):
        raise ValueError("Evidence pack does not match the current case snapshot; regenerate and review")
    observations = pack.get("observations")
    validate_observations(observations)
    if pack.get("observations_sha256") != digest(observations):
        raise ValueError("Evidence pack observations changed after preparation")
    ids = {item["id"] for item in observations}
    selections = []
    for field in ("key_observation_ids", "control_observation_ids"):
        values = pack.get(field)
        if (not isinstance(values, list) or not values or any(not isinstance(v, str) for v in values)
                or len(set(values)) != len(values) or not set(values) <= ids):
            raise ValueError(f"Invalid {field}")
        selections.append(set(values))
    if selections[0] & selections[1]:
        raise ValueError("Key and control observations must be disjoint")
    if not all(pack.get(field) is True for field in (
        "duplicate_evidence_reviewed", "description_leakage_reviewed", "control_length_reviewed"
    )):
        raise ValueError("Evidence pack requires duplicate/leakage/control-length review")
    return pack


def select_observations(pack: dict, condition: str) -> list[dict]:
    if condition not in CONDITIONS:
        raise ValueError(f"Unknown evidence condition: {condition}")
    keys = set(pack["key_observation_ids"])
    controls = set(pack["control_observation_ids"])
    return [item for item in pack["observations"] if (
        condition == "full"
        or condition == "key_only" and item["id"] in keys
        or condition == "key_removed" and item["id"] not in keys
        or condition == "matched_control" and item["id"] not in controls
    )]


def public_observations(records: list[dict]) -> list[dict]:
    return [{key: record[key] for key in ("id", "command", "text", "exit_code", "truncated")
             if key in record} for record in records]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Prepare a pending-review RQ3 evidence pack; no LLM or Docker.")
    parser.add_argument("instance_id")
    parser.add_argument("--observations", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    observations = load_observations(Path(args.observations))
    root = Path(__file__).resolve().parents[3]
    case = CaseDefinition.load(instance_dir(root, args.instance_id))
    pack = {"schema_version": 1, "instance_id": args.instance_id.upper(),
            "review_status": "pending", "reviewer": "", "source_kind": "reviewed_observations",
            "case_sha256": digest(case_provenance(case, "")["case_files_sha256"]),
            "observations": observations, "observations_sha256": digest(observations),
            "key_observation_ids": [], "control_observation_ids": [],
            "duplicate_evidence_reviewed": False, "description_leakage_reviewed": False,
            "control_length_reviewed": False, "review_notes": ""}
    path = Path(args.output)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(pack, indent=2) + "\n")
    print(f"Pending-review pack: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
