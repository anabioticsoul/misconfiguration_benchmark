"""Expose only the frozen evidence bundle, never host or Docker execution."""

import json
from typing import Self
from collections.abc import Sequence
from pydantic import Field
from openhands.sdk import Action, Observation
from openhands.sdk.tool.tool import ToolAnnotations, ToolDefinition, ToolExecutor


class ReviewEvidenceAction(Action):
    path: str = Field(description="Exact evidence ID from the prompt inventory.")


class ReviewEvidenceObservation(Observation):
    pass


class ReviewEvidenceExecutor(ToolExecutor):
    def __init__(self, evidence):
        self.evidence = evidence

    def __call__(self, action, conversation=None):
        if action.path not in self.evidence:
            return ReviewEvidenceObservation.from_text("Unknown evidence ID", is_error=True)
        return ReviewEvidenceObservation.from_text(json.dumps(self.evidence[action.path], ensure_ascii=False))


class ReviewEvidenceTool(ToolDefinition[ReviewEvidenceAction, ReviewEvidenceObservation]):
    @classmethod
    def create(cls, evidence, **kwargs) -> Sequence[Self]:
        return [cls(description="Read a frozen case evidence item. No writes or commands are supported.",
                    action_type=ReviewEvidenceAction, observation_type=ReviewEvidenceObservation,
                    executor=ReviewEvidenceExecutor(evidence),
                    annotations=ToolAnnotations(readOnlyHint=True, destructiveHint=False,
                                                idempotentHint=True, openWorldHint=False))]


def register_review_tools(evidence):
    from openhands.sdk import register_tool
    register_tool("ReviewEvidenceTool", ReviewEvidenceTool.create(evidence)[0])
    return ["ReviewEvidenceTool"]
