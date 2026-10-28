"""Deterministic scoring for structured root-cause diagnosis predictions."""

from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from agents.manager.case import CaseDefinition


MAX_RANKED_LOCATIONS = 5
LOCATION_FIELDS = ("component", "path", "section", "option")


@dataclass(frozen=True)
class DiagnosisPrediction:
    type_id: str | None
    subtype_id: str | None
    locations: tuple[dict[str, str], ...]
    claims: object = None


def parse_diagnosis_response(response: str) -> DiagnosisPrediction:
    """Parse the single JSON object required in an agent's final response."""
    payload = _extract_json_object(response)
    classification = _mapping(payload.get("classification"))
    raw_locations = payload.get("ranked_locations", [])
    if not isinstance(raw_locations, list):
        raise ValueError("ranked_locations must be an array")
    if len(raw_locations) > MAX_RANKED_LOCATIONS:
        raise ValueError(f"ranked_locations must contain at most {MAX_RANKED_LOCATIONS} entries")

    locations: list[dict[str, str]] = []
    for raw_location in raw_locations:
        location = _mapping(raw_location)
        normalized = {
            field: _normalize_text(location[field])
            for field in LOCATION_FIELDS
            if isinstance(location.get(field), str) and location[field].strip()
        }
        if not normalized:
            raise ValueError("each ranked location must identify at least one field")
        locations.append(normalized)

    return DiagnosisPrediction(
        type_id=_optional_upper(classification.get("type_id")),
        subtype_id=_optional_upper(classification.get("subtype_id")),
        locations=tuple(locations),
        claims=payload.get("claims"),
    )


def prediction_document(prediction: DiagnosisPrediction) -> dict[str, object]:
    document = {
        "classification": {
            "type_id": prediction.type_id,
            "subtype_id": prediction.subtype_id,
        },
        "ranked_locations": list(prediction.locations),
    }
    if prediction.claims is not None:
        document["claims"] = prediction.claims
    return document


def score_diagnosis(
    case: CaseDefinition,
    prediction: DiagnosisPrediction,
) -> dict[str, object]:
    """Score category and ranked locations without inspecting repair artifacts."""
    metadata = json.loads(
        (case.case_dir / "meta" / "metadata.json").read_text(encoding="utf-8")
    )
    oracle = _mapping(metadata.get("private_oracle"))
    classification = _mapping(oracle.get("classification"))
    subtype_id = _required_text(classification.get("category_id"), "category_id")
    type_id = subtype_id.split("-", 1)[0]
    targets = tuple(
        _normalize_target(target)
        for target in _sequence(oracle.get("faulty_targets"))
    )
    if not targets:
        raise ValueError(f"{case.instance_id} does not define faulty_targets")

    diagnosis_oracle = _mapping(oracle.get("diagnosis_oracle"))
    explicit_component = _optional_text(diagnosis_oracle.get("component"))
    component = _normalize_text(explicit_component or case.software_name)
    component_rank = _first_component_rank(prediction.locations, component)
    target_ranks = [_first_target_rank(prediction.locations, target) for target in targets]
    target_rank = min((rank for rank in target_ranks if rank is not None), default=None)

    location_metrics = {
        "component": _ranking_metrics(component_rank),
        "configuration_target": _multi_target_metrics(
            prediction.locations,
            targets,
        ),
    }
    subtype_exact = prediction.subtype_id == subtype_id
    type_exact = prediction.type_id == type_id
    joint = {
        "joint_at_1": subtype_exact
        and bool(location_metrics["configuration_target"]["hit_at_1"]),
        "joint_at_3": subtype_exact
        and bool(location_metrics["configuration_target"]["hit_at_3"]),
        "joint_at_5": subtype_exact
        and bool(location_metrics["configuration_target"]["hit_at_5"]),
    }
    return {
        "instance_id": case.instance_id,
        "gold": {
            "type_id": type_id,
            "subtype_id": subtype_id,
            "component": component,
            "component_oracle_source": (
                "diagnosis_oracle" if explicit_component else "software_name_fallback"
            ),
            "faulty_targets": list(targets),
        },
        "prediction": prediction_document(prediction),
        "classification": {
            "type_exact": type_exact,
            "subtype_exact": subtype_exact,
        },
        "localization": location_metrics,
        "joint": joint,
    }


def aggregate_diagnosis_results(
    results: list[dict[str, object]],
    taxonomy_path: Path,
) -> dict[str, object]:
    """Report standard classification and ranking metrics across scored cases."""
    taxonomy = json.loads(taxonomy_path.read_text(encoding="utf-8"))
    subtype_ids = [
        subtype["id"]
        for category in taxonomy["types"]
        for subtype in category["subtypes"]
    ]
    type_ids = [category["id"] for category in taxonomy["types"]]
    gold_subtypes = [str(_mapping(result.get("gold")).get("subtype_id", "")) for result in results]
    predicted_subtypes = [
        _optional_upper(_mapping(_mapping(result.get("prediction")).get("classification")).get("subtype_id"))
        for result in results
    ]
    gold_types = [str(_mapping(result.get("gold")).get("type_id", "")) for result in results]
    predicted_types = [
        _optional_upper(_mapping(_mapping(result.get("prediction")).get("classification")).get("type_id"))
        for result in results
    ]
    return {
        "evaluated_cases": len(results),
        "root_cause_type": _classification_report(gold_types, predicted_types, type_ids),
        "root_cause_subtype": _classification_report(
            gold_subtypes, predicted_subtypes, subtype_ids
        ),
        "component_localization": _mean_metric(
            results, ("localization", "component")
        ),
        "configuration_target_localization": _mean_metric(
            results, ("localization", "configuration_target")
        ),
        "joint_diagnosis": {
            key: _mean_bool(results, ("joint", key))
            for key in ("joint_at_1", "joint_at_3", "joint_at_5")
        },
        "component_oracle_sources": dict(
            sorted(
                Counter(
                    str(_mapping(result.get("gold")).get("component_oracle_source"))
                    for result in results
                ).items()
            )
        ),
        "by_subtype": _breakdown_by_subtype(results),
    }


def _extract_json_object(response: str) -> dict[str, Any]:
    candidates = re.findall(r"```(?:json)?\s*(\{.*?\})\s*```", response, re.DOTALL | re.IGNORECASE)
    candidates.append(response.strip())
    for candidate in candidates:
        try:
            value = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            return value
    raise ValueError("final response must contain one valid JSON object")


def _normalize_target(value: object) -> dict[str, str]:
    target = _mapping(value)
    normalized = {
        field: _normalize_text(_required_text(target.get(field), field))
        for field in ("path", "section", "option")
    }
    return normalized


def _first_component_rank(locations: tuple[dict[str, str], ...], component: str) -> int | None:
    for index, location in enumerate(locations, start=1):
        if location.get("component") == component:
            return index
    return None


def _first_target_rank(
    locations: tuple[dict[str, str], ...],
    target: dict[str, str],
) -> int | None:
    for index, location in enumerate(locations, start=1):
        if all(location.get(field) == value for field, value in target.items()):
            return index
    return None


def _ranking_metrics(rank: int | None) -> dict[str, float | bool]:
    return {
        "hit_at_1": rank == 1,
        "hit_at_3": rank is not None and rank <= 3,
        "hit_at_5": rank is not None and rank <= 5,
        "mrr": round(1 / rank, 8) if rank is not None else 0.0,
    }


def _multi_target_metrics(
    locations: tuple[dict[str, str], ...],
    targets: tuple[dict[str, str], ...],
) -> dict[str, float | bool]:
    ranks = [_first_target_rank(locations, target) for target in targets]
    best_rank = min((rank for rank in ranks if rank is not None), default=None)
    metrics: dict[str, float | bool] = _ranking_metrics(best_rank)
    for limit in (1, 3, 5):
        retrieved = locations[:limit]
        hits = sum(
            any(all(location.get(field) == value for field, value in target.items()) for location in retrieved)
            for target in targets
        )
        metrics[f"recall_at_{limit}"] = round(hits / len(targets), 8)
        metrics[f"precision_at_{limit}"] = round(hits / limit, 8)
    precision_sum = 0.0
    hits = 0
    for rank, location in enumerate(locations, start=1):
        if any(all(location.get(field) == value for field, value in target.items()) for target in targets):
            hits += 1
            precision_sum += hits / rank
    metrics["map_at_5"] = round(precision_sum / len(targets), 8)
    return metrics


def _classification_report(
    gold: list[str],
    predicted: list[str | None],
    labels: list[str],
) -> dict[str, object]:
    per_label: dict[str, dict[str, float | int]] = {}
    for label in labels:
        true_positive = sum(actual == label and guess == label for actual, guess in zip(gold, predicted))
        false_positive = sum(actual != label and guess == label for actual, guess in zip(gold, predicted))
        false_negative = sum(actual == label and guess != label for actual, guess in zip(gold, predicted))
        support = gold.count(label)
        precision = true_positive / (true_positive + false_positive) if true_positive + false_positive else 0.0
        recall = true_positive / (true_positive + false_negative) if true_positive + false_negative else 0.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        per_label[label] = {
            "precision": round(precision, 8),
            "recall": round(recall, 8),
            "f1": round(f1, 8),
            "support": support,
        }
    observed = [item for item in per_label.values() if item["support"]]
    exact_accuracy = sum(actual == guess for actual, guess in zip(gold, predicted)) / len(gold) if gold else 0.0
    true_positive = sum(actual == guess for actual, guess in zip(gold, predicted))
    false_positive = sum(
        actual != guess and guess is not None for actual, guess in zip(gold, predicted)
    )
    false_negative = sum(actual != guess for actual, guess in zip(gold, predicted))
    micro_precision = true_positive / (true_positive + false_positive) if true_positive + false_positive else 0.0
    micro_recall = true_positive / (true_positive + false_negative) if true_positive + false_negative else 0.0
    micro_f1 = 2 * micro_precision * micro_recall / (micro_precision + micro_recall) if micro_precision + micro_recall else 0.0
    normalized_predictions = [
        prediction if prediction in labels else "__invalid_or_missing__"
        for prediction in predicted
    ]
    confusion_matrix = {
        label: {
            guess: sum(
                actual == label and prediction == guess
                for actual, prediction in zip(gold, normalized_predictions)
            )
            for guess in [*labels, "__invalid_or_missing__"]
            if sum(
                actual == label and prediction == guess
                for actual, prediction in zip(gold, normalized_predictions)
            )
        }
        for label in labels
        if any(actual == label for actual in gold)
    }
    return {
        "accuracy": round(exact_accuracy, 8),
        "macro_f1": round(_mean([float(item["f1"]) for item in observed]), 8),
        "micro_precision": round(micro_precision, 8),
        "micro_recall": round(micro_recall, 8),
        "micro_f1": round(micro_f1, 8),
        "per_label": per_label,
        "confusion_matrix": confusion_matrix,
    }


def _mean_metric(results: list[dict[str, object]], path: tuple[str, str]) -> dict[str, float]:
    metric_names = sorted(
        {
            name
            for result in results
            for name, value in _mapping(_mapping(result.get(path[0])).get(path[1])).items()
            if isinstance(value, int | float | bool)
        }
    )
    return {
        name: round(
            _mean([
                float(_mapping(_mapping(result.get(path[0])).get(path[1])).get(name, 0.0))
                for result in results
            ]),
            8,
        )
        for name in metric_names
    }


def _mean_bool(results: list[dict[str, object]], path: tuple[str, str]) -> float:
    return round(
        _mean([float(bool(_mapping(result.get(path[0])).get(path[1], False))) for result in results]),
        8,
    )


def _breakdown_by_subtype(results: list[dict[str, object]]) -> dict[str, dict[str, float | int]]:
    grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
    for result in results:
        grouped[str(_mapping(result.get("gold")).get("subtype_id", "unknown"))].append(result)
    return {
        subtype: {
            "support": len(group),
            "subtype_accuracy": _mean([
                float(bool(_mapping(result.get("classification")).get("subtype_exact")))
                for result in group
            ]),
            "target_hit_at_1": _mean([
                float(bool(_mapping(_mapping(item.get("localization")).get("configuration_target")).get("hit_at_1")))
                for item in group
            ]),
            "target_mrr": _mean([
                float(_mapping(_mapping(item.get("localization")).get("configuration_target")).get("mrr", 0.0))
                for item in group
            ]),
        }
        for subtype, group in sorted(grouped.items())
    }


def _mapping(value: object) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _sequence(value: object) -> list[object]:
    return value if isinstance(value, list) else []


def _required_text(value: object, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field} must be a non-empty string")
    return value


def _optional_text(value: object) -> str | None:
    return value.strip() if isinstance(value, str) and value.strip() else None


def _optional_upper(value: object) -> str | None:
    return value.strip().upper() if isinstance(value, str) and value.strip() else None


def _normalize_text(value: str) -> str:
    return value.strip().lower()


def _mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0
