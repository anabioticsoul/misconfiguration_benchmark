"""Persistent failure records shared by all benchmark agent entrypoints."""

from __future__ import annotations

import json
import logging
import os
import re
import shutil
import sys
import traceback
from contextvars import ContextVar
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, TextIO


_SECRET_PATTERNS = (
    re.compile(r"\bsk-[A-Za-z0-9_-]+"),
    re.compile(r"(?i)(bearer\s+)[A-Za-z0-9._~-]+"),
    re.compile(r'(?i)("?(?:api_)?key"?\s*[:=]\s*["\']?)[^\s,"\'}]+'),
)


@dataclass
class AgentFailureContext:
    agent_role: str
    instance_id: str | None = None
    run_dir: Path | None = None
    error: BaseException | None = None
    traceback_text: str | None = None


class _ConsoleTee:
    """Write Python console output to its original stream and an archive."""

    def __init__(self, stream: TextIO, archive: TextIO) -> None:
        self._stream = stream
        self._archive = archive

    @property
    def encoding(self) -> str | None:
        return self._stream.encoding

    def write(self, text: str) -> int:
        written = self._stream.write(text)
        self._archive.write(text)
        self._archive.flush()
        return written

    def flush(self) -> None:
        self._stream.flush()
        self._archive.flush()

    def isatty(self) -> bool:
        return self._stream.isatty()

    def fileno(self) -> int:
        return self._stream.fileno()


_CONTEXT: ContextVar[AgentFailureContext | None] = ContextVar(
    "misconfigbench_agent_failure_context",
    default=None,
)


def configure_agent_failure_context(
    *,
    instance_id: str,
    run_dir: Path | None = None,
) -> None:
    """Attach case and run information to the current agent invocation."""
    context = _CONTEXT.get()
    if context is None:
        return
    context.instance_id = instance_id
    if run_dir is not None:
        context.run_dir = run_dir


def capture_agent_exception(error: BaseException) -> None:
    """Preserve a caught exception so the entrypoint can persist it once."""
    context = _CONTEXT.get()
    if context is None:
        return
    context.error = error
    context.traceback_text = traceback.format_exc()


def run_agent_entrypoint(
    agent_role: str,
    main: Callable[[], int],
) -> int:
    """Run an agent main function and persist any abnormal exit."""
    context = AgentFailureContext(agent_role=agent_role)
    token = _CONTEXT.set(context)
    try:
        with _capture_console(context):
            try:
                exit_code = main()
            except BaseException as error:
                context.error = error
                context.traceback_text = traceback.format_exc()
                _write_failure_record(context, _system_exit_code(error, default=1))
                raise

            if exit_code != 0:
                _write_failure_record(context, exit_code)
            return exit_code
    finally:
        _CONTEXT.reset(token)


def _system_exit_code(error: BaseException, *, default: int) -> int:
    if isinstance(error, SystemExit) and isinstance(error.code, int):
        return error.code
    return default


def _write_failure_record(context: AgentFailureContext, exit_code: int) -> Path:
    repository_root = _repository_root(context)
    log_dir = repository_root / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc)
    record: dict[str, object] = {
        "timestamp": timestamp.isoformat(),
        "agent_role": context.agent_role,
        "instance_id": context.instance_id,
        "exit_code": exit_code,
        "pid": os.getpid(),
        "command": sys.argv,
    }
    if context.run_dir is not None:
        record["run_dir"] = str(context.run_dir)
        result_path = context.run_dir / "result.json"
        if result_path.is_file():
            record["result_path"] = str(result_path)
    if context.error is not None:
        record["exception_type"] = type(context.error).__name__
        record["error"] = _redact(str(context.error))
    if context.traceback_text:
        record["traceback"] = _redact(context.traceback_text)

    filename_stem = "-".join(
        (
            timestamp.strftime("%Y%m%dT%H%M%S.%fZ"),
            _safe_filename_fragment(context.agent_role),
            _safe_filename_fragment(context.instance_id or "unknown"),
            str(record["pid"]),
        )
    )
    for sequence in range(1000):
        suffix = "" if sequence == 0 else f"-{sequence}"
        log_path = log_dir / f"{filename_stem}{suffix}.json"
        try:
            with log_path.open("x", encoding="utf-8") as log_file:
                json.dump(record, log_file, ensure_ascii=True, indent=2)
                log_file.write("\n")
            return log_path
        except FileExistsError:
            continue
    raise RuntimeError("Could not allocate a unique agent failure log filename")


class _capture_console:
    """Capture console streams and standard-library log records for one run."""

    def __init__(self, context: AgentFailureContext) -> None:
        self._context = context
        self._started_at = datetime.now(timezone.utc)
        self._initial_path: Path | None = None
        self._archive: TextIO | None = None
        self._stdout: TextIO | None = None
        self._stderr: TextIO | None = None
        self._handler: logging.Handler | None = None

    def __enter__(self) -> "_capture_console":
        initial_dir = Path.cwd() / "logs" / "console" / "unknown"
        initial_dir.mkdir(parents=True, exist_ok=True)
        self._initial_path = _unique_console_log_path(
            initial_dir,
            self._started_at,
            self._context.agent_role,
        )
        self._archive = self._initial_path.open("x", encoding="utf-8")
        self._stdout = sys.stdout
        self._stderr = sys.stderr
        sys.stdout = _ConsoleTee(self._stdout, self._archive)  # type: ignore[assignment]
        sys.stderr = _ConsoleTee(self._stderr, self._archive)  # type: ignore[assignment]

        self._handler = logging.FileHandler(self._initial_path, encoding="utf-8")
        self._handler.setFormatter(
            logging.Formatter(
                "%(asctime)s %(levelname)s %(name)s: %(message)s"
            )
        )
        logging.getLogger().addHandler(self._handler)
        return self

    def __exit__(self, exc_type, exc_value, traceback_value) -> None:  # noqa: ANN001
        if self._handler is not None:
            logging.getLogger().removeHandler(self._handler)
            self._handler.close()
        if self._stdout is not None:
            sys.stdout = self._stdout
        if self._stderr is not None:
            sys.stderr = self._stderr
        if self._archive is not None:
            self._archive.close()
        if self._initial_path is None:
            return

        repository_root = _repository_root(self._context)
        case_dir = _safe_filename_fragment(self._context.instance_id or "unknown")
        destination_dir = repository_root / "logs" / "console" / case_dir
        destination_dir.mkdir(parents=True, exist_ok=True)
        destination = _unique_console_log_path(
            destination_dir,
            self._started_at,
            self._context.agent_role,
        )
        shutil.move(str(self._initial_path), destination)


def _unique_console_log_path(
    directory: Path,
    timestamp: datetime,
    agent_role: str,
) -> Path:
    stem = "-".join(
        (
            timestamp.strftime("%Y%m%dT%H%M%S.%fZ"),
            _safe_filename_fragment(agent_role),
            str(os.getpid()),
        )
    )
    for sequence in range(1000):
        suffix = "" if sequence == 0 else f"-{sequence}"
        candidate = directory / f"{stem}{suffix}.log"
        if not candidate.exists():
            return candidate
    raise RuntimeError("Could not allocate a unique console log filename")


def _repository_root(context: AgentFailureContext) -> Path:
    if context.run_dir is not None:
        for parent in (context.run_dir, *context.run_dir.parents):
            if (parent / "agents").is_dir() and (parent / "instances").is_dir():
                return parent
    return Path.cwd()


def _redact(text: str) -> str:
    for pattern in _SECRET_PATTERNS:
        text = pattern.sub(r"\1<redacted>" if pattern.groups else "<redacted>", text)
    return text


def _safe_filename_fragment(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-") or "unknown"


__all__ = [
    "capture_agent_exception",
    "configure_agent_failure_context",
    "run_agent_entrypoint",
]
