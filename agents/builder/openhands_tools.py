from __future__ import annotations

from collections.abc import Sequence
from typing import Literal, Self

from openhands.sdk import Action, Observation
from openhands.sdk.tool.tool import ToolAnnotations, ToolDefinition, ToolExecutor
from pydantic import Field

from agents.manager.workspace import WorkspaceFiles


_registered_workspace_root = None


class BuildWorkspaceAction(Action):
    operation: Literal["read", "write", "replace"] = Field(
        description="File operation within the isolated builder workspace."
    )
    path: str = Field(description="Relative path within the builder workspace.")
    content: str | None = Field(default=None)
    old_text: str | None = Field(default=None)
    new_text: str | None = Field(default=None)


class BuildWorkspaceObservation(Observation):
    pass


class BuildWorkspaceExecutor(ToolExecutor):
    def __init__(self, workspace: WorkspaceFiles) -> None:
        self.workspace = workspace

    def __call__(
        self,
        action: BuildWorkspaceAction,
        conversation=None,  # noqa: ANN001, ARG002
    ) -> BuildWorkspaceObservation:
        try:
            if action.operation == "read":
                return BuildWorkspaceObservation.from_text(
                    self.workspace.read(action.path)
                )
            if action.operation == "write":
                if action.content is None:
                    raise ValueError("content is required for write")
                self.workspace.write(action.path, action.content)
                return BuildWorkspaceObservation.from_text(f"Wrote {action.path}")
            if action.old_text is None or action.new_text is None:
                raise ValueError("old_text and new_text are required for replace")
            self.workspace.replace(action.path, action.old_text, action.new_text)
            return BuildWorkspaceObservation.from_text(f"Updated {action.path}")
        except Exception as exc:  # noqa: BLE001
            return BuildWorkspaceObservation.from_text(str(exc), is_error=True)


class BuildWorkspaceTool(
    ToolDefinition[BuildWorkspaceAction, BuildWorkspaceObservation]
):
    @classmethod
    def create(
        cls,
        workspace: WorkspaceFiles,
        **_: object,
    ) -> Sequence[Self]:
        return [
            cls(
                description=(
                    "Read and edit files under the isolated builder workspace. "
                    "Paths must be relative. Prepare the structured build spec, "
                    "Dockerfile templates, and context files; Docker execution and "
                    "benchmark validation are performed by the host orchestrator."
                ),
                action_type=BuildWorkspaceAction,
                observation_type=BuildWorkspaceObservation,
                executor=BuildWorkspaceExecutor(workspace),
                annotations=ToolAnnotations(
                    readOnlyHint=False,
                    destructiveHint=True,
                    idempotentHint=False,
                    openWorldHint=False,
                ),
            )
        ]


def register_builder_tools(workspace_root) -> list[str]:  # noqa: ANN001
    global _registered_workspace_root

    resolved_workspace = workspace_root.resolve()
    if _registered_workspace_root == resolved_workspace:
        return ["BuildWorkspaceTool"]

    from openhands.sdk import register_tool

    tool = BuildWorkspaceTool.create(WorkspaceFiles(resolved_workspace))[0]
    register_tool("BuildWorkspaceTool", tool)
    _registered_workspace_root = resolved_workspace
    return ["BuildWorkspaceTool"]
