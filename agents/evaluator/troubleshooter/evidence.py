"""Auditable observation ledger and deterministic RQ3 measurements."""

from __future__ import annotations

import json
import re
import time
from pathlib import Path

from agents.evaluator.oracles import MissingOracle, digest, private_annotation, reviewed


CLAIM_KINDS = ("symptom", "root_cause", "localization")


class ObservationLedger:
    def __init__(self, path: Path):
        self.path = path
        self.count = 0
        self.started = time.monotonic()

    def record(self, command: str, text: str, exit_code: int | None) -> str:
        self.count += 1
        identifier = f"obs-{self.count:04d}"
        visible = f"Observation ID: {identifier}\n{text}"
        record = {"id": identifier, "command": command, "text": visible,
                  "exit_code": exit_code, "truncated": False,
                  "elapsed_seconds": time.monotonic() - self.started}
        with self.path.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(record, ensure_ascii=True) + "\n")
        return visible


def load_observations(path: Path) -> list[dict]:
    records = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    validate_observations(records)
    return records


def validate_observations(records: object) -> None:
    if not isinstance(records, list):
        raise ValueError("observations must be a list")
    identifiers = []
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("text"), str):
            raise ValueError("Every observation needs text")
        identifier = record.get("id")
        if not isinstance(identifier, str) or not re.fullmatch(r"obs-\d+", identifier):
            raise ValueError("Invalid observation ID")
        identifiers.append(identifier)
    if len(set(identifiers)) != len(identifiers):
        raise ValueError("Duplicate observation IDs")


def load_evidence_oracle(case) -> dict:
    oracle = private_annotation(case, "evidence_oracle")
    facts = oracle.get("facts")
    if not isinstance(facts, list) or not facts:
        raise MissingOracle("evidence_oracle requires facts")
    ids = []
    for fact in facts:
        if not isinstance(fact, dict) or not isinstance(fact.get("id"), str):
            raise MissingOracle("Invalid evidence fact")
        ids.append(fact["id"])
        rules = fact.get("alternatives")
        if not isinstance(rules, list) or not rules:
            raise MissingOracle("Evidence fact requires alternative matching rules")
        for rule in rules:
            if not isinstance(rule, dict):
                raise MissingOracle("Invalid evidence rule")
            for field in ("command_pattern", "output_pattern"):
                if not isinstance(rule.get(field), str) or not rule[field]:
                    raise MissingOracle(f"Evidence rule requires {field}")
                re.compile(rule[field])
    sufficient = oracle.get("sufficient_sets")
    if len(set(ids)) != len(ids) or not isinstance(sufficient, list) or not sufficient:
        raise MissingOracle("Invalid evidence IDs or sufficient_sets")
    if any(not isinstance(group, list) or not group or not set(group) <= set(ids) for group in sufficient):
        raise MissingOracle("Sufficient sets must reference known facts")
    return oracle


def audit_evidence(case, prediction: dict, observations: list[dict], review: dict | None = None) -> dict:
    validate_observations(observations)
    by_id = {item["id"]: item for item in observations}
    claims = prediction.get("claims", [])
    if not isinstance(claims, list):
        raise ValueError("claims must be an array")
    if any(not isinstance(claim, dict) or claim.get("kind") not in CLAIM_KINDS
           or not isinstance(claim.get("text"), str) or not claim["text"].strip()
           or not isinstance(claim.get("evidence_refs", []), list)
           or any(not isinstance(ref, str) for ref in claim.get("evidence_refs", [])) for claim in claims):
        raise ValueError("Invalid evidence claim")
    if len({claim["kind"] for claim in claims}) != len(claims):
        raise ValueError("Return at most one claim per kind")
    refs = [(claim["kind"], ref) for claim in claims for ref in set(claim.get("evidence_refs", []))]
    valid = sum(ref in by_id for _, ref in refs)
    binding = digest({"prediction": prediction, "observations": observations})
    result = {
        "binding_sha256": binding,
        "observation_count": len(observations),
        "citation_count": len(refs),
        "valid_citation_count": valid,
        "citation_validity": valid / len(refs) if refs else None,
        "missing_claim_kinds": sorted(set(CLAIM_KINDS) - {c["kind"] for c in claims}),
        "invalid_references": [{"kind": kind, "id": ref} for kind, ref in refs if ref not in by_id],
        "support_status": "not_reviewed",
        "core_claim_support_rate": None,
        "acquisition_status": "not_annotated",
        "sufficient_evidence_acquired": None,
    }
    try:
        oracle = load_evidence_oracle(case)
    except MissingOracle as exc:
        result["acquisition_note"] = str(exc)
    else:
        matched = {}
        first = None
        for index, observation in enumerate(observations, start=1):
            for fact in oracle["facts"]:
                if any(observation.get("exit_code") == rule.get("exit_code", 0)
                       and re.search(rule["command_pattern"], observation.get("command", ""))
                       and re.search(rule["output_pattern"], observation["text"])
                       for rule in fact["alternatives"]):
                    matched.setdefault(fact["id"], observation["id"])
            if first is None and any(set(group) <= matched.keys() for group in oracle["sufficient_sets"]):
                first = {"tool_calls": index, "elapsed_seconds": observation.get("elapsed_seconds")}
        result.update(acquisition_status="reviewed_rule_matching", matched_facts=matched,
                      sufficient_evidence_acquired=first is not None, first_sufficient_evidence=first)
    if review is not None:
        reviewed(review, "claim support review")
        if review.get("binding_sha256") != binding:
            raise ValueError("Claim support review does not match this diagnosis and observation ledger")
        judgments = review.get("judgments")
        if not isinstance(judgments, dict) or set(judgments) != set(CLAIM_KINDS):
            raise ValueError("Review must judge every core claim kind")
        claims_by_kind = {claim["kind"]: claim for claim in claims}
        for kind, verdict in judgments.items():
            if verdict not in ("supported", "unsupported", "missing"):
                raise ValueError("Invalid claim support verdict")
            claim = claims_by_kind.get(kind)
            if verdict == "supported" and (not claim or not claim.get("evidence_refs")
                                           or not all(ref in by_id for ref in claim["evidence_refs"])):
                raise ValueError("Supported claims require valid evidence references")
            if (verdict == "missing") != (claim is None):
                raise ValueError("Missing verdict must agree with the submitted claims")
        result.update(support_status="human_reviewed", judgments=judgments,
                      core_claim_support_rate=sum(v == "supported" for v in judgments.values()) / len(CLAIM_KINDS))
    result["review_template"] = {
        "review_status": "pending", "reviewer": "", "source_kind": "human_trajectory_audit",
        "binding_sha256": binding, "judgments": {kind: "pending" for kind in CLAIM_KINDS},
    }
    return result
