"""Shared Jinja template rendering."""

from __future__ import annotations

from typing import Any


def render_template(template: str, context: dict[str, Any]) -> str:
    try:
        from jinja2 import Template
    except ImportError:
        rendered = template
        for key, value in context.items():
            rendered = rendered.replace("{{ " + key + " }}", str(value))
            rendered = rendered.replace("{{" + key + "}}", str(value))
        return rendered
    return Template(template, keep_trailing_newline=True).render(**context)
