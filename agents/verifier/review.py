"""Evidence collection and strict parsing for advisory consistency review."""

import hashlib
import json
import shlex
import subprocess
from pathlib import Path

from agents.manager import ContainerRuntime

DIMENSIONS = ("description", "environment", "patch", "tests")
LIMIT = 48000


def add_evidence(evidence, name, text):
    evidence[name] = {"text": text[:LIMIT], "truncated": len(text) > LIMIT,
                      "sha256": hashlib.sha256(text.encode()).hexdigest()}


def collect_evidence(case, repo_root: Path, validation: dict) -> dict:
    evidence = {}
    origin = repo_root / "assets" / case.instance_id[:2] / f"{case.instance_id}.md"
    add_evidence(evidence, "source/description.md", origin.read_text(encoding="utf-8"))
    for path in sorted(case.case_dir.rglob("*")):
        relative = path.relative_to(case.case_dir)
        if relative.parts[0] not in {"meta", "build", "harness", "instance.json"}:
            continue
        if not path.is_file() or path.suffix in {".key", ".gz", ".tar", ".jar", ".pyc"}:
            continue
        if not path.resolve().is_relative_to(case.case_dir.resolve()):
            raise ValueError(f"Case symlink escapes directory: {relative}")
        if path.stat().st_size > LIMIT:
            add_evidence(evidence, f"case/{relative.as_posix()}", "[FILE TOO LARGE: inspection required]")
            evidence[f"case/{relative.as_posix()}"]["truncated"] = True
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        add_evidence(evidence, f"case/{relative.as_posix()}", text)
    add_evidence(evidence, "validation/results.json", json.dumps(validation, ensure_ascii=False))
    inspected = subprocess.run(["docker", "image", "inspect", case.image_name,
                                "--format", "{{.Id}} {{.Os}}/{{.Architecture}}"],
                               capture_output=True, text=True, check=True, timeout=30)
    add_evidence(evidence, "image/identity", inspected.stdout)
    with ContainerRuntime(case) as runtime:
        for path in case.allowed_modified_files:
            target = "/" + path.lstrip("/")
            result = runtime.execute(f"head -c {LIMIT + 1} -- {shlex.quote(target)}", timeout_seconds=15)
            if result.exit_code != 0:
                raise ValueError(f"Cannot inspect runtime configuration {target}: {result.stderr}")
            add_evidence(evidence, "image" + target, result.stdout)
    return evidence


def parse_review(response: str, evidence: dict) -> dict:
    text = response.strip()
    if text.startswith("```json\n") and text.endswith("```"):
        text = text[8:-3].strip()
    document = json.loads(text)
    checks = document.get("checks") if isinstance(document, dict) else None
    if not isinstance(checks, dict) or set(checks) != set(DIMENSIONS):
        raise ValueError("Review must contain exactly four checks: " + ", ".join(DIMENSIONS))
    for name, check in checks.items():
        if not isinstance(check, dict) or check.get("status") not in {"pass", "fail", "uncertain"}:
            raise ValueError(f"Invalid status for {name}")
        if not isinstance(check.get("reason"), str) or not check["reason"].strip():
            raise ValueError(f"Missing reason for {name}")
        refs = check.get("evidence")
        if not isinstance(refs, list) or not refs or any(not isinstance(r, str) or r not in evidence for r in refs):
            raise ValueError(f"Invalid evidence references for {name}")
    states = {check["status"] for check in checks.values()}
    verdict = "inconsistent" if "fail" in states else "needs_review" if "uncertain" in states else "consistent"
    if verdict == "consistent" and any(e["truncated"] for e in evidence.values()):
        verdict = "needs_review"
    return {"checks": checks, "verdict": verdict,
            "limitations": "LLM advisory assessment; citations are validated, semantic correctness is not guaranteed."}
