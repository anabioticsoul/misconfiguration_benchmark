from __future__ import annotations

from pathlib import Path

from agents.manager.case import CaseDefinition
from agents.manager.templates import render_template


DEFAULT_PROMPT_TEMPLATE = "prompts/misconfig_diagnosis.j2"


def resolve_prompt_template(case: CaseDefinition) -> Path:
    template_path = case.repo_root / DEFAULT_PROMPT_TEMPLATE
    if not template_path.is_file():
        raise FileNotFoundError(f"Prompt template not found: {template_path}")
    return template_path


def render_diagnosis_prompt(case: CaseDefinition, taxonomy: str) -> str:
    template = resolve_prompt_template(case).read_text(encoding="utf-8")
    context = {
        "instance_id": case.instance_id,
        "task_type": case.task_type,
        "software_name": case.software_name,
        "software_version": case.software_version,
        "public_problem": case.read_public_problem().strip(),
        "taxonomy": taxonomy.strip(),
    }
    return render_template(template, context).strip() + "\n"
