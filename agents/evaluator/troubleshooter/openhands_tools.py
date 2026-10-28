from __future__ import annotations

from collections.abc import Sequence
from typing import Self
from pathlib import Path

from pydantic import Field

from openhands.sdk import Action, Observation, register_tool
from openhands.sdk.tool.tool import ToolAnnotations, ToolDefinition, ToolExecutor

from agents.manager.container_runtime import ContainerRuntime
from agents.evaluator.troubleshooter.evidence import ObservationLedger


class DiagnosticTerminalAction(Action):
    command: str = Field(
        description=(
            "Read-only diagnostic shell command to run inside the isolated case "
            "container. Inspect files, logs, processes, and reproduce failures."
        )
    )
    timeout_seconds: int = Field(default=30, ge=1, le=120)


class DiagnosticTerminalObservation(Observation):
    pass


class DiagnosticTerminalExecutor(ToolExecutor):
    def __init__(self, runtime: ContainerRuntime, ledger: ObservationLedger | None = None) -> None:
        self.runtime = runtime
        self.ledger = ledger

    def __call__(
        self,
        action: DiagnosticTerminalAction,
        conversation=None,  # noqa: ANN001, ARG002
    ) -> DiagnosticTerminalObservation:
        try:
            result = self.runtime.execute(
                action.command,
                timeout_seconds=action.timeout_seconds,
                user="65534:65534",
            )
            text = result.render()
            if self.ledger:
                text = self.ledger.record(action.command, text, result.exit_code)
            return DiagnosticTerminalObservation.from_text(text)
        except Exception as exc:  # noqa: BLE001
            text = str(exc)
            if self.ledger:
                text = self.ledger.record(action.command, text, None)
            return DiagnosticTerminalObservation.from_text(text, is_error=True)


class DiagnosticTerminalTool(
    ToolDefinition[DiagnosticTerminalAction, DiagnosticTerminalObservation]
):
    @classmethod
    def create(
        cls,
        runtime: ContainerRuntime,
        ledger: ObservationLedger | None = None,
        **_: object,
    ) -> Sequence[Self]:
        return [
            cls(
                description=(
                    "Run a diagnostic command inside an ephemeral benchmark "
                    "container. Do not modify files, services, or configuration; "
                    "the task is diagnosis only. Commands never run on the host."
                ),
                action_type=DiagnosticTerminalAction,
                observation_type=DiagnosticTerminalObservation,
                executor=DiagnosticTerminalExecutor(runtime, ledger),
                annotations=ToolAnnotations(
                    readOnlyHint=True,
                    destructiveHint=False,
                    idempotentHint=False,
                    openWorldHint=False,
                ),
            )
        ]


def register_diagnostic_tools(runtime: ContainerRuntime, observations_path: Path | None = None) -> list[str]:
    ledger = ObservationLedger(observations_path) if observations_path else None
    terminal = DiagnosticTerminalTool.create(runtime, ledger=ledger)[0]
    register_tool("DiagnosticTerminalTool", terminal)
    return ["DiagnosticTerminalTool"]
