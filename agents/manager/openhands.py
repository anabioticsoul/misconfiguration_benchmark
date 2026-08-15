"""Shared OpenHands conversation lifecycle for benchmark agents."""

from __future__ import annotations

import asyncio
import os
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path


DEFAULT_SUBSCRIPTION_MODEL = "gpt-5.4"


@dataclass(frozen=True)
class OpenHandsConfig:
    model: str
    api_key: str | None = None
    base_url: str | None = None
    subscription_login: bool = False
    max_iterations: int = 40
    max_runtime_seconds: int = 900

    @property
    def should_use_subscription_login(self) -> bool:
        if self.subscription_login:
            return True
        return not self.api_key and not self.base_url


def run_openhands_agent(
    task_prompt: str,
    tool_names: Sequence[str],
    run_dir: Path,
    config: OpenHandsConfig,
    *,
    workspace_dir: Path | None = None,
) -> str:
    os.environ.setdefault("OPENHANDS_SUPPRESS_BANNER", "1")

    from openhands.sdk import Agent, Conversation, LLM, Tool
    from openhands.sdk.conversation.response_utils import get_agent_final_response

    if config.should_use_subscription_login:
        llm = LLM.subscription_login(vendor="openai", model=config.model)
    else:
        llm = LLM(
            model=config.model,
            api_key=config.api_key,
            base_url=config.base_url,
        )

    workspace = workspace_dir or run_dir / "agent_workspace"
    workspace.mkdir(parents=True, exist_ok=True)
    trajectory_path = run_dir / "trajectory.jsonl"

    with trajectory_path.open("w", encoding="utf-8") as trajectory:

        def record_event(event) -> None:  # noqa: ANN001
            trajectory.write(event.model_dump_json(exclude_none=True) + "\n")
            trajectory.flush()

        agent = Agent(
            llm=llm,
            tools=[Tool(name=name) for name in tool_names],
            include_default_tools=["ThinkTool", "FinishTool"],
        )
        conversation = Conversation(
            agent=agent,
            workspace=workspace,
            persistence_dir=run_dir / "openhands_state",
            callbacks=[record_event],
            max_iteration_per_run=config.max_iterations,
            visualizer=None,
            delete_on_close=False,
        )
        try:
            conversation.send_message(task_prompt)
            asyncio.run(
                _run_conversation_with_timeout(
                    conversation,
                    config.max_runtime_seconds,
                )
            )
            return get_agent_final_response(conversation.state.events)
        finally:
            conversation.close()


async def _run_conversation_with_timeout(
    conversation,  # noqa: ANN001
    timeout_seconds: int | float,
) -> None:
    """Run one conversation with an interruptible wall-clock deadline."""
    if timeout_seconds <= 0:
        await conversation.arun()
        return
    task = asyncio.create_task(conversation.arun())
    done, _ = await asyncio.wait({task}, timeout=timeout_seconds)
    if task in done:
        await task
        return
    conversation.interrupt()
    await task
    raise TimeoutError(
        f"OpenHands conversation exceeded {timeout_seconds:g} seconds"
    )
