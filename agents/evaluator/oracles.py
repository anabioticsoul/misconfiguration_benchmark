"""Host-only, reviewed evaluation annotations. Never expose whole metadata."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from agents.manager.case import CaseDefinition


class MissingOracle(ValueError):
    pass


def digest(value: object) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=True).encode()).hexdigest()


def reviewed(document: object, name: str) -> dict:
    if not isinstance(document, dict) or document.get("review_status") != "reviewed":
        raise MissingOracle(f"{name}: requires review_status=reviewed")
    for field in ("reviewer", "source_kind"):
        if not isinstance(document.get(field), str) or not document[field].strip():
            raise MissingOracle(f"{name}: missing {field}")
    return document


def private_annotation(case: CaseDefinition, name: str) -> dict:
    metadata = json.loads((case.case_dir / "meta/metadata.json").read_text())
    return reviewed(metadata.get("private_oracle", {}).get(name), name)


def repair_context(case: CaseDefinition, mode: str) -> dict:
    if mode not in ("none", "location", "root_cause"):
        raise ValueError(f"Unknown repair context: {mode}")
    if mode == "none":
        return {}
    annotation = private_annotation(case, "repair_context")
    location = annotation.get("location")
    if not isinstance(location, dict) or not isinstance(location.get("path"), str):
        raise MissingOracle("repair_context: requires location.path")
    output = {"location": {key: location[key] for key in ("path", "section", "option")
                           if isinstance(location.get(key), str)}}
    for key in ("component", "layer"):
        if not isinstance(annotation.get(key), str) or not annotation[key].strip():
            raise MissingOracle(f"repair_context: requires {key}")
        output[key] = annotation[key]
    if mode == "root_cause":
        if not isinstance(annotation.get("cause"), str) or not annotation["cause"].strip():
            raise MissingOracle("repair_context: requires cause")
        output["cause"] = annotation["cause"]
    return output


def case_provenance(case: CaseDefinition, prompt: str) -> dict:
    files = [case.case_dir / "instance.json", case.case_dir / "meta/metadata.json",
             case.public_problem, case.case_dir / case.reference_patch, case.evaluator,
             case.case_dir / case.reproduce_script]
    files.extend(case.case_dir / path for path in (*case.fail_to_pass_scripts, *case.pass_to_pass_scripts))
    return {"prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
            "case_files_sha256": {str(path.relative_to(case.case_dir)): hashlib.sha256(path.read_bytes()).hexdigest()
                                  for path in sorted(set(files)) if path.is_file()},
            "image_reference": case.image_name}
