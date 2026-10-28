from __future__ import annotations

import json
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

from agents.manager.batch import discover_cases, run_case_batch
from agents.evaluator import run_case
from agents.evaluator.troubleshooter import run_case as troubleshooter
from agents.manager import OpenHandsConfig


class BatchTest(unittest.TestCase):
    def test_discovery_uses_numeric_order_and_skips_incomplete_cases(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for case_id in ("CA10", "CA2", "CA3", "CB1"):
                directory = root / "instances" / case_id[:2] / case_id
                directory.mkdir(parents=True)
                if case_id != "CA3":
                    (directory / "required").touch()

            def load(directory, **kwargs):
                return SimpleNamespace(
                    instance_id=directory.name, validate_files=lambda: None,
                    reproduce_script="required", reference_patch="required",
                    fail_to_pass_scripts=("required",), pass_to_pass_scripts=("required",),
                )

            with patch("agents.manager.batch.CaseDefinition.load", side_effect=load):
                candidates, skipped = discover_cases(root)
            self.assertEqual(candidates, ["CA2", "CA10", "CB1"])
            self.assertEqual(skipped[0]["instance_id"], "CA3")

    def test_verification_gates_evaluation_and_failures_do_not_stop_batch(self) -> None:
        verify = Mock(side_effect=[1, 0, 0])
        evaluate = Mock(side_effect=[SystemExit(1), 0])
        with tempfile.TemporaryDirectory() as temporary, redirect_stdout(StringIO()), patch(
            "agents.manager.batch.discover_cases", return_value=(["CA1", "CA2", "CA3"], [])
        ):
            destination = Path(temporary) / "batch"
            code = run_case_batch(Path(temporary), destination, task="fixer", experiment={},
                                  verify=verify, evaluate=evaluate)
            result = json.loads((destination / "batch_result.json").read_text())
        self.assertEqual(code, 1)
        self.assertEqual([call.args[0] for call in evaluate.call_args_list], ["CA2", "CA3"])
        self.assertEqual([item["status"] for item in result["cases"]],
                         ["verification_failed", "evaluation_failed", "completed"])

    def test_keyboard_interrupt_stops_batch_and_saves_progress(self) -> None:
        verify = Mock(side_effect=KeyboardInterrupt)
        evaluate = Mock()
        with tempfile.TemporaryDirectory() as temporary, redirect_stdout(StringIO()), patch(
            "agents.manager.batch.discover_cases", return_value=(["CA1", "CA2"], [])
        ):
            destination = Path(temporary) / "batch"
            with self.assertRaises(KeyboardInterrupt):
                run_case_batch(Path(temporary), destination, task="fixer", experiment={},
                               verify=verify, evaluate=evaluate)
            result = json.loads((destination / "batch_result.json").read_text())
        evaluate.assert_not_called()
        self.assertEqual(result["status"], "interrupted")
        self.assertEqual([item["status"] for item in result["cases"]], ["interrupted", "pending"])

    def test_empty_batch_does_not_report_success(self) -> None:
        with tempfile.TemporaryDirectory() as temporary, redirect_stdout(StringIO()), patch(
            "agents.manager.batch.discover_cases", return_value=([], [])
        ):
            self.assertEqual(run_case_batch(
                Path(temporary), Path(temporary) / "batch", task="fixer", experiment={},
                verify=Mock(), evaluate=Mock(),
            ), 1)

    def test_evaluator_batch_wires_callbacks_and_preserves_model_args(self) -> None:
        config = OpenHandsConfig(model="test-model", provider="openlux")
        with tempfile.TemporaryDirectory() as temporary, patch.object(
            run_case, "load_repository_env"
        ), patch.object(troubleshooter, "_openhands_config", return_value=config), patch.object(
            troubleshooter, "main", return_value=0
        ) as evaluate, patch("agents.builder.validate_case.main", return_value=0) as verify, patch.object(
            run_case, "run_agent_entrypoint", side_effect=lambda role, main: main()
        ), patch.object(run_case, "run_case_batch") as batch:
            destination = Path(temporary) / "batch"

            def run_batch(*args, **kwargs):
                kwargs["verify"]("CA1", destination / "verification" / "CA1")
                kwargs["evaluate"]("CA1", destination / "CA1")
                return 0

            batch.side_effect = run_batch
            self.assertEqual(run_case.main([
                "--task", "troubleshooter", "--all", "--batch-dir", str(destination),
                "--model", "test-model", "--llm-provider", "openlux",
            ]), 0)
            self.assertEqual(batch.call_args.kwargs["experiment"]["model"], "test-model")
            self.assertEqual(verify.call_args.args[0][0], "CA1")
            self.assertIn("test-model", evaluate.call_args.args[0])
            self.assertEqual(evaluate.call_args.args[0][-1], str(destination / "CA1"))

    def test_batch_rejects_shared_run_dir_before_running_cases(self) -> None:
        with patch.object(run_case, "load_repository_env"), patch.object(
            run_case, "run_agent_entrypoint", side_effect=lambda role, main: main()
        ), patch.object(run_case, "run_case_batch") as batch:
            with self.assertRaisesRegex(ValueError, "--run-dir"):
                run_case.main(["--task", "fixer", "--all", "--run-dir", "/tmp/shared"])
            batch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
