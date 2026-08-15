from __future__ import annotations

from pathlib import Path

from agents.manager.templates import render_template


DEFAULT_PROMPT_TEMPLATE = "prompts/instance_builder.j2"


def resolve_prompt_template(repo_root: Path) -> Path:
    template_path = repo_root / DEFAULT_PROMPT_TEMPLATE
    if not template_path.is_file():
        raise FileNotFoundError(f"Builder prompt template not found: {template_path}")
    return template_path


def render_builder_prompt(
    repo_root: Path,
    instance_id: str,
    description: str,
    taxonomy: str,
    image_inventory: str,
) -> str:
    template = resolve_prompt_template(repo_root).read_text(encoding="utf-8")
    context = {
        "instance_id": instance_id,
        "public_problem": description.strip(),
        "taxonomy": taxonomy.strip(),
        "image_inventory": image_inventory.strip(),
    }
    return render_template(template, context).strip() + "\n"
