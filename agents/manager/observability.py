"""Shared stage-level observability for benchmark agents."""

from __future__ import annotations

import os
import threading
from collections.abc import Callable
from functools import wraps
from time import perf_counter
from typing import Any

os.environ.setdefault("OPENHANDS_SUPPRESS_BANNER", "1")

from openhands.sdk.observability.laminar import observe
from openhands.sdk.logger import get_logger


logger = get_logger(__name__)


def observe_stage(
    agent_role: str,
    stage: str,
    *,
    ignore_inputs: list[str] | None = None,
    ignore_output: bool = False,
    output_formatter: Callable[[Any], str] | None = None,
    log_context: Callable[..., str] | None = None,
    heartbeat_seconds: float | None = None,
) -> Callable[[Callable[..., Any]], Callable[..., Any]]:
    """Trace one benchmark phase and expose its progress in the console."""
    stage_name = f"misconfigbench.{agent_role}.{stage}"

    def decorator(func: Callable[..., Any]) -> Callable[..., Any]:
        observed = observe(
            name=stage_name,
            ignore_inputs=ignore_inputs,
            ignore_output=ignore_output,
            output_formatter=output_formatter,
            metadata={"agent_role": agent_role, "stage": stage},
            tags=["misconfigbench", agent_role],
        )(func)

        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            started_at = perf_counter()
            context = log_context(*args, **kwargs) if log_context else ""
            context_suffix = f" ({context})" if context else ""
            interval = (
                heartbeat_seconds
                if heartbeat_seconds is not None
                else float(
                    os.getenv("MISCONFIGBENCH_HEARTBEAT_SECONDS", "30")
                )
            )
            heartbeat_stop = threading.Event()

            def report_heartbeat() -> None:
                while not heartbeat_stop.wait(interval):
                    logger.info(
                        "Still running %s stage: %s%s (elapsed %.0fs)",
                        agent_role,
                        stage,
                        context_suffix,
                        perf_counter() - started_at,
                    )

            logger.info(
                "Starting %s stage: %s%s",
                agent_role,
                stage,
                context_suffix,
            )
            heartbeat_thread: threading.Thread | None = None
            if interval > 0:
                heartbeat_thread = threading.Thread(
                    target=report_heartbeat,
                    name=f"misconfigbench-{agent_role}-{stage}-heartbeat",
                    daemon=True,
                )
                heartbeat_thread.start()
            try:
                result = observed(*args, **kwargs)
            except Exception as exc:
                logger.error(
                    "Failed %s stage: %s%s after %.2fs (%s: %s)",
                    agent_role,
                    stage,
                    context_suffix,
                    perf_counter() - started_at,
                    type(exc).__name__,
                    exc,
                )
                raise
            finally:
                heartbeat_stop.set()
                if heartbeat_thread is not None:
                    heartbeat_thread.join(timeout=1)
            logger.info(
                "Completed %s stage: %s%s in %.2fs",
                agent_role,
                stage,
                context_suffix,
                perf_counter() - started_at,
            )
            return result

        return wrapper

    return decorator


__all__ = ["observe_stage"]
