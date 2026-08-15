from __future__ import annotations

from collections.abc import Sequence
from typing import Literal, Self

from pydantic import Field

from openhands.sdk import Action, Observation
from openhands.sdk.tool.tool import ToolAnnotations, ToolDefinition, ToolExecutor

from agents.manager.container_runtime import ContainerRuntime


class ContainerTerminalAction(Action):
    command: str = Field(description="Bash command to run inside the case container.")
    timeout_seconds: int = Field(default=30, ge=1, le=120)


class ContainerTerminalObservation(Observation):
    pass


class ContainerTerminalExecutor(ToolExecutor):
    def __init__(self, runtime: ContainerRuntime) -> None:
        self.runtime = runtime

    def __call__(
        self,
        action: ContainerTerminalAction,
        conversation=None,  # noqa: ANN001, ARG002
    ) -> ContainerTerminalObservation:
        try:
            result = self.runtime.execute(
                action.command,
                timeout_seconds=action.timeout_seconds,
            )
            return ContainerTerminalObservation.from_text(result.render())
        except Exception as exc:  # noqa: BLE001
            return ContainerTerminalObservation.from_text(str(exc), is_error=True)


class ContainerTerminalTool(
    ToolDefinition[ContainerTerminalAction, ContainerTerminalObservation]
):
    @classmethod
    def create(
        cls,
        runtime: ContainerRuntime,
        **_: object,
    ) -> Sequence[Self]:
        return [
            cls(
                description=(
                    "Run a bash command inside the isolated benchmark case container. "
                    "Use this to inspect the environment, reproduce the failure, and "
                    "test repairs. Commands do not run on the evaluator host."
                ),
                action_type=ContainerTerminalAction,
                observation_type=ContainerTerminalObservation,
                executor=ContainerTerminalExecutor(runtime),
                annotations=ToolAnnotations(
                    readOnlyHint=False,
                    destructiveHint=True,
                    idempotentHint=False,
                    openWorldHint=False,
                ),
            )
        ]


class ContainerFileEditorAction(Action):
    operation: Literal["read", "write", "replace"] = Field(
        description="File operation to perform inside the case container."
    )
    path: str = Field(description="Absolute file path inside the case container.")
    content: str | None = Field(
        default=None,
        description="Complete new file contents for a write operation.",
    )
    old_text: str | None = Field(
        default=None,
        description="Exact existing text for a replace operation.",
    )
    new_text: str | None = Field(
        default=None,
        description="Replacement text for a replace operation.",
    )


class ContainerFileEditorObservation(Observation):
    pass


class ContainerFileEditorExecutor(ToolExecutor):
    def __init__(self, runtime: ContainerRuntime) -> None:
        self.runtime = runtime

    def __call__(
        self,
        action: ContainerFileEditorAction,
        conversation=None,  # noqa: ANN001, ARG002
    ) -> ContainerFileEditorObservation:
        try:
            if action.operation == "read":
                return ContainerFileEditorObservation.from_text(
                    self.runtime.read_file(action.path)
                )

            if action.operation == "write":
                if action.content is None:
                    raise ValueError("content is required for write")
                self.runtime.write_file(action.path, action.content)
                return ContainerFileEditorObservation.from_text(f"Wrote {action.path}")

            if action.old_text is None or action.new_text is None:
                raise ValueError("old_text and new_text are required for replace")
            content = self.runtime.read_file(action.path)
            occurrences = content.count(action.old_text)
            if occurrences != 1:
                raise ValueError(
                    f"Expected exactly one old_text occurrence, found {occurrences}"
                )
            self.runtime.write_file(
                action.path,
                content.replace(action.old_text, action.new_text, 1),
            )
            return ContainerFileEditorObservation.from_text(f"Updated {action.path}")
        except Exception as exc:  # noqa: BLE001
            return ContainerFileEditorObservation.from_text(str(exc), is_error=True)


class ContainerFileEditorTool(
    ToolDefinition[ContainerFileEditorAction, ContainerFileEditorObservation]
):
    @classmethod
    def create(
        cls,
        runtime: ContainerRuntime,
        **_: object,
    ) -> Sequence[Self]:
        return [
            cls(
                description=(
                    "Read or edit files inside the isolated benchmark case container. "
                    "Reading and writing accept absolute paths. Use replace for a "
                    "focused edit or write for complete file contents. Final scoring "
                    "is based on the evaluator's hidden patch policy."
                ),
                action_type=ContainerFileEditorAction,
                observation_type=ContainerFileEditorObservation,
                executor=ContainerFileEditorExecutor(runtime),
                annotations=ToolAnnotations(
                    readOnlyHint=False,
                    destructiveHint=True,
                    idempotentHint=False,
                    openWorldHint=False,
                ),
            )
        ]


def register_container_tools(runtime: ContainerRuntime) -> list[str]:
    from openhands.sdk import register_tool

    terminal = ContainerTerminalTool.create(runtime)[0]
    editor = ContainerFileEditorTool.create(runtime)[0]
    register_tool("ContainerTerminalTool", terminal)
    register_tool("ContainerFileEditorTool", editor)
    return ["ContainerTerminalTool", "ContainerFileEditorTool"]
