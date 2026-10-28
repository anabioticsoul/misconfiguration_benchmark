from __future__ import annotations

from pathlib import Path
import json

from agents.evaluator.oracles import repair_context

from agents.manager.case import CaseDefinition
from agents.manager.templates import render_template


DEFAULT_PROMPT_TEMPLATE = "prompts/misconfig_troubleshooting.j2"


def resolve_prompt_template(case: CaseDefinition) -> Path:
    relative_path = case.prompt_protocol.get("template", DEFAULT_PROMPT_TEMPLATE)
    template_path = case.repo_root / relative_path
    if not template_path.is_file():
        raise FileNotFoundError(f"Prompt template not found: {template_path}")
    return template_path


def render_case_prompt(case: CaseDefinition, mode: str = "none") -> str:
    template = resolve_prompt_template(case).read_text(encoding="utf-8")
    context = {
        "instance_id": case.instance_id,
        "task_type": case.task_type,
        "software_name": case.software_name,
        "software_version": case.software_version,
        "public_problem": case.read_public_problem().strip(),
    }
    prompt = render_template(template, context).strip() + "\n"
    if mode != "none":
        hint = repair_context(case, mode)
        oracle_template = (case.repo_root / "prompts/misconfig_repair_oracle.j2").read_text()
        prompt += "\n" + render_template(oracle_template, {"repair_context": json.dumps(hint, indent=2)})
    return prompt
