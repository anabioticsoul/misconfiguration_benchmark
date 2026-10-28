"""Shared OpenHands conversation lifecycle for benchmark agents."""

from __future__ import annotations

import asyncio
import json
import os
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

from openhands.sdk.logger import get_logger


DEFAULT_SUBSCRIPTION_MODEL = "gpt-5.4"
DEFAULT_LLM_PROVIDER = "openai_subscription"
OPENLUX_LLM_PROVIDER = "openlux"

logger = get_logger(__name__)


@dataclass(frozen=True)
class OpenHandsConfig:
    model: str
    provider: str = DEFAULT_LLM_PROVIDER
    api_key: str | None = None
    base_url: str | None = None
    subscription_login: bool = False
    max_iterations: int = 40
    max_runtime_seconds: int = 900
    llm_num_retries: int = 8
    llm_retry_multiplier: float = 2.0
    llm_retry_min_wait_seconds: int = 2
    llm_retry_max_wait_seconds: int = 30
    llm_request_timeout_seconds: int = 600
    input_cost_per_million_tokens: float | None = None
    output_cost_per_million_tokens: float | None = None

    @classmethod
    def from_environment(cls, **kwargs: object) -> "OpenHandsConfig":
        """Build configuration from one explicit credential provider."""
        provider = str(kwargs.pop("provider", DEFAULT_LLM_PROVIDER))
        model = kwargs.pop("model", None)
        api_key = kwargs.pop("api_key", None)
        base_url = kwargs.pop("base_url", None)
        subscription_login = bool(kwargs.pop("subscription_login", False))

        if provider == OPENLUX_LLM_PROVIDER:
            if subscription_login:
                raise ValueError(
                    "--subscription-login cannot be used with --llm-provider openlux"
                )
            api_key = api_key or os.getenv("OPENLUX_API_KEY")
            base_url = base_url or os.getenv("OPENLUX_API_URL")
            missing = [
                name
                for name, value in (
                    ("OPENLUX_API_KEY", api_key),
                    ("OPENLUX_API_URL", base_url),
                )
                if not value
            ]
            if missing:
                raise ValueError(
                    "OpenLux API authentication requires " + ", ".join(missing)
                )
            model = model or os.getenv("OPENLUX_MODEL")
            if not model:
                raise ValueError(
                    "OpenLux API authentication requires --model or OPENLUX_MODEL"
                )
        elif provider == DEFAULT_LLM_PROVIDER:
            if api_key or base_url:
                raise ValueError(
                    "OpenAI subscription authentication does not accept --api-key "
                    "or --base-url; use --llm-provider openlux instead"
                )
            model = model or os.getenv("LLM_MODEL") or DEFAULT_SUBSCRIPTION_MODEL
            subscription_login = True
        else:
            raise ValueError(
                f"Unsupported LLM provider {provider!r}; expected "
                f"{DEFAULT_LLM_PROVIDER!r} or {OPENLUX_LLM_PROVIDER!r}"
            )

        return cls(
            model=str(model),
            provider=provider,
            api_key=str(api_key) if api_key else None,
            base_url=str(base_url) if base_url else None,
            subscription_login=subscription_login,
            **kwargs,
            llm_num_retries=_environment_int(
                "MISCONFIGBENCH_LLM_NUM_RETRIES", 8
            ),
            llm_retry_multiplier=_environment_float(
                "MISCONFIGBENCH_LLM_RETRY_MULTIPLIER", 2.0
            ),
            llm_retry_min_wait_seconds=_environment_int(
                "MISCONFIGBENCH_LLM_RETRY_MIN_WAIT_SECONDS", 2
            ),
            llm_retry_max_wait_seconds=_environment_int(
                "MISCONFIGBENCH_LLM_RETRY_MAX_WAIT_SECONDS", 30
            ),
            llm_request_timeout_seconds=_environment_int(
                "MISCONFIGBENCH_LLM_REQUEST_TIMEOUT_SECONDS", 600
            ),
            input_cost_per_million_tokens=_optional_environment_float(
                "MISCONFIGBENCH_LLM_INPUT_COST_PER_1M_TOKENS"
            ),
            output_cost_per_million_tokens=_optional_environment_float(
                "MISCONFIGBENCH_LLM_OUTPUT_COST_PER_1M_TOKENS"
            ),
        )

    @property
    def sdk_model(self) -> str:
        # OpenLux serves model aliases through its OpenAI-compatible endpoint.
        # Keep the user-facing model identity unchanged for result grouping.
        if self.provider == OPENLUX_LLM_PROVIDER and not self.model.startswith("openai/"):
            return f"openai/{self.model}"
        return self.model

    @property
    def should_use_subscription_login(self) -> bool:
        if self.provider != DEFAULT_LLM_PROVIDER:
            return False
        # Retain the dataclass's historical behavior for direct callers. Agent
        # entrypoints use from_environment(), which always sets this to True.
        return self.subscription_login or not self.api_key and not self.base_url

    def llm_kwargs(self) -> dict[str, int | float | object]:
        kwargs: dict[str, int | float | object] = {
            "num_retries": self.llm_num_retries,
            "retry_multiplier": self.llm_retry_multiplier,
            "retry_min_wait": self.llm_retry_min_wait_seconds,
            "retry_max_wait": self.llm_retry_max_wait_seconds,
            "timeout": self.llm_request_timeout_seconds,
            "retry_listener": _log_llm_retry,
        }
        if not self.should_use_subscription_login:
            if self.input_cost_per_million_tokens is not None:
                kwargs["input_cost_per_token"] = (
                    self.input_cost_per_million_tokens / 1_000_000
                )
            if self.output_cost_per_million_tokens is not None:
                kwargs["output_cost_per_token"] = (
                    self.output_cost_per_million_tokens / 1_000_000
                )
        return kwargs


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
        llm = LLM.subscription_login(
            vendor="openai",
            model=config.model,
            **config.llm_kwargs(),
        )
    else:
        logger.info("Using OpenLux API model %s", config.model)
        llm = LLM(
            model=config.sdk_model,
            api_key=config.api_key,
            base_url=config.base_url,
            **config.llm_kwargs(),
        )

    workspace = workspace_dir or run_dir / "agent_workspace"
    workspace.mkdir(parents=True, exist_ok=True)
    trajectory_path = run_dir / "trajectory.jsonl"

    with trajectory_path.open("w", encoding="utf-8") as trajectory:

        def record_event(event) -> None:  # noqa: ANN001
            trajectory.write(event.model_dump_json(exclude_none=True) + "\n")
            trajectory.flush()
            _log_agent_progress(event)

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
            _write_agent_usage(run_dir / "agent_usage.json", llm, config)
            conversation.close()


def summarize_agent_usage(run_dir: Path) -> dict[str, object]:
    """Aggregate all OpenHands rollouts below one agent run directory."""
    records: list[dict[str, object]] = []
    for usage_path in sorted(run_dir.rglob("agent_usage.json")):
        try:
            record = json.loads(usage_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            logger.warning("Ignoring invalid agent usage record: %s", usage_path)
            continue
        if not isinstance(record, dict):
            continue
        record["rollout_dir"] = str(usage_path.parent.relative_to(run_dir))
        records.append(record)

    token_names = (
        "prompt_tokens",
        "completion_tokens",
        "cache_read_tokens",
        "cache_write_tokens",
        "reasoning_tokens",
    )
    tokens = {
        name: sum(
            _nonnegative_int(
                _as_mapping(record.get("tokens")).get(name)
            )
            for record in records
        )
        for name in token_names
    }
    estimates = [
        float(record["estimated_cost_usd"])
        for record in records
        if isinstance(record.get("estimated_cost_usd"), int | float)
    ]
    statuses = {str(record.get("cost_status", "unavailable")) for record in records}
    if not records:
        cost_status = "not_recorded"
    elif estimates and len(estimates) == len(records):
        cost_status = "estimated"
    elif estimates:
        cost_status = "partial_estimate"
    elif statuses == {"subscription_not_metered"}:
        cost_status = "subscription_not_metered"
    else:
        cost_status = "unavailable"

    return {
        "rollouts": len(records),
        "requests": sum(_nonnegative_int(record.get("requests")) for record in records),
        "tokens": tokens,
        "estimated_cost_usd": round(sum(estimates), 8) if estimates else None,
        "cost_status": cost_status,
        "rollout_usage": records,
    }


def _write_agent_usage(path: Path, llm: object, config: OpenHandsConfig) -> None:
    metrics = getattr(llm, "metrics", None)
    usage = getattr(metrics, "accumulated_token_usage", None)
    configured_rates = (
        config.input_cost_per_million_tokens is not None
        or config.output_cost_per_million_tokens is not None
    )
    raw_cost = float(getattr(metrics, "accumulated_cost", 0.0) or 0.0)
    requests = len(getattr(metrics, "token_usages", []) or [])
    tokens = {
        name: _nonnegative_int(getattr(usage, name, 0))
        for name in (
            "prompt_tokens",
            "completion_tokens",
            "cache_read_tokens",
            "cache_write_tokens",
            "reasoning_tokens",
        )
    }
    if config.should_use_subscription_login:
        estimated_cost: float | None = None
        cost_status = "subscription_not_metered"
    elif configured_rates or raw_cost > 0:
        estimated_cost = round(raw_cost, 8)
        cost_status = "configured_rates" if configured_rates else "sdk_estimate"
    else:
        estimated_cost = None
        cost_status = "unavailable"

    record = {
        "provider": config.provider,
        "model": config.model,
        "requests": requests,
        "tokens": tokens,
        "estimated_cost_usd": estimated_cost,
        "cost_status": cost_status,
    }
    path.write_text(json.dumps(record, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def _as_mapping(value: object) -> dict[str, object]:
    return value if isinstance(value, dict) else {}


def _nonnegative_int(value: object) -> int:
    return value if isinstance(value, int) and value >= 0 else 0


def _environment_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None or not value.strip():
        return default
    try:
        parsed = int(value)
    except ValueError as exc:
        raise ValueError(f"{name} must be a non-negative integer") from exc
    if parsed < 0:
        raise ValueError(f"{name} must be a non-negative integer")
    return parsed


def _environment_float(name: str, default: float) -> float:
    value = os.getenv(name)
    if value is None or not value.strip():
        return default
    try:
        parsed = float(value)
    except ValueError as exc:
        raise ValueError(f"{name} must be a non-negative number") from exc
    if parsed < 0:
        raise ValueError(f"{name} must be a non-negative number")
    return parsed


def _optional_environment_float(name: str) -> float | None:
    value = os.getenv(name)
    if value is None or not value.strip():
        return None
    return _environment_float(name, 0.0)


def _log_llm_retry(
    attempt: int,
    total_attempts: int,
    error: BaseException | None,
) -> None:
    error_name = type(error).__name__ if error is not None else "unknown error"
    logger.warning(
        "LLM request failed (%d/%d, %s); retrying with configured backoff",
        attempt,
        total_attempts,
        error_name,
    )


def _log_agent_progress(event: object) -> None:
    """Mirror concise agent actions from the trajectory to the console."""
    if getattr(event, "source", None) != "agent":
        return

    action = getattr(event, "action", None)
    if action is None:
        if getattr(event, "thought", None):
            logger.info("OpenHands agent response received")
        return

    tool_name = getattr(event, "tool_name", "tool")
    operation = getattr(action, "operation", None)
    target = (
        getattr(action, "path", None)
        or getattr(action, "command", None)
        or ""
    )
    detail = " ".join(part for part in (operation, target) if part)
    logger.info(
        "OpenHands agent action: %s%s",
        tool_name,
        f" ({detail})" if detail else "",
    )


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
