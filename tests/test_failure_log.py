from __future__ import annotations

import json
import logging
import tempfile
import unittest
from pathlib import Path

from agents.manager.failure_log import (
    capture_agent_exception,
    configure_agent_failure_context,
    run_agent_entrypoint,
)


class AgentFailureLogTest(unittest.TestCase):
    def test_console_output_and_logging_are_archived_by_case(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            repository_root = Path(temporary_dir)
            (repository_root / "agents").mkdir()
            (repository_root / "instances").mkdir()
            run_dir = repository_root / "runs" / "fixer-ca1"
            run_dir.mkdir(parents=True)

            def successful_main() -> int:
                configure_agent_failure_context(instance_id="CA1", run_dir=run_dir)
                print("console output")
                logging.getLogger("test.console").warning("logger output")
                return 0

            self.assertEqual(run_agent_entrypoint("fixer", successful_main), 0)

            log_files = list((repository_root / "logs" / "console" / "ca1").glob("*.log"))
            self.assertEqual(len(log_files), 1)
            contents = log_files[0].read_text(encoding="utf-8")
            self.assertIn("console output", contents)
            self.assertIn("logger output", contents)

    def test_nonzero_exit_records_captured_exception_and_run_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            repository_root = Path(temporary_dir)
            (repository_root / "agents").mkdir()
            (repository_root / "instances").mkdir()
            run_dir = repository_root / "runs" / "builder-ca1"
            run_dir.mkdir(parents=True)
            (run_dir / "result.json").write_text("{}\n", encoding="utf-8")

            def failing_main() -> int:
                configure_agent_failure_context(instance_id="CA1", run_dir=run_dir)
                try:
                    raise ValueError("invalid key sk-secret-value")
                except ValueError as error:
                    capture_agent_exception(error)
                    return 1

            self.assertEqual(run_agent_entrypoint("builder", failing_main), 1)

            log_files = list((repository_root / "logs").glob("*.json"))
            self.assertEqual(len(log_files), 1)
            self.assertRegex(log_files[0].name, r"-builder-ca1-\d+\.json$")
            record = json.loads(log_files[0].read_text(encoding="utf-8"))
            self.assertEqual(record["agent_role"], "builder")
            self.assertEqual(record["instance_id"], "CA1")
            self.assertEqual(record["exit_code"], 1)
            self.assertEqual(record["exception_type"], "ValueError")
            self.assertIn("<redacted>", record["error"])
            self.assertNotIn("sk-secret-value", record["error"])
            self.assertIn("ValueError", record["traceback"])
            self.assertEqual(record["run_dir"], str(run_dir))

    def test_system_exit_is_recorded_before_it_is_reraised(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            repository_root = Path(temporary_dir)
            (repository_root / "agents").mkdir()
            (repository_root / "instances").mkdir()
            run_dir = repository_root / "runs" / "verifier-ca1"
            run_dir.mkdir(parents=True)

            def exiting_main() -> int:
                configure_agent_failure_context(instance_id="CA1", run_dir=run_dir)
                raise SystemExit(7)

            with self.assertRaisesRegex(SystemExit, "7"):
                run_agent_entrypoint("verifier", exiting_main)

            log_files = list((repository_root / "logs").glob("*.json"))
            self.assertEqual(len(log_files), 1)
            self.assertRegex(log_files[0].name, r"-verifier-ca1-\d+\.json$")
            record = json.loads(log_files[0].read_text(encoding="utf-8"))
            self.assertEqual(record["agent_role"], "verifier")
            self.assertEqual(record["exit_code"], 7)
            self.assertEqual(record["exception_type"], "SystemExit")


if __name__ == "__main__":
    unittest.main()
