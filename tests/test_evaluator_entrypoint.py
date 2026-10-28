from __future__ import annotations

import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

from agents.evaluator import run_case
from agents.evaluator.fixer import run_case as fixer
from agents.evaluator.troubleshooter import run_case as troubleshooter
from agents.manager import OpenHandsConfig


REPO_ROOT = Path(__file__).resolve().parents[1]


class EvaluatorEntrypointTest(unittest.TestCase):
    def test_dispatch_preserves_arguments_exit_code_and_log_role(self) -> None:
        for task in ("troubleshooter", "fixer"):
            with self.subTest(task=task), patch(
                f"agents.evaluator.{task}.run_case.main", return_value=1
            ) as run_task, patch(
                "agents.evaluator.run_case.run_agent_entrypoint",
                side_effect=lambda role, main: main(),
            ) as entrypoint:
                arguments = ["CA1", "--model", "openai/test-model", "--llm-provider", "openlux"]
                self.assertEqual(run_case.main(["--task", task, *arguments]), 1)
                run_task.assert_called_once_with(arguments)
                self.assertEqual(entrypoint.call_args.args[0], task)

    def test_paths_after_moving_packages(self) -> None:
        self.assertEqual(fixer.REPO_ROOT, REPO_ROOT)
        self.assertEqual(troubleshooter.REPO_ROOT, REPO_ROOT)

    def test_launch_presets_select_task_and_model(self) -> None:
        document = json.loads((REPO_ROOT / ".vscode/launch.json").read_text())
        combinations = set()
        for config in document["configurations"]:
            if config.get("module") != "agents.evaluator.run_case":
                continue
            args = config["args"]
            task = args[args.index("--task") + 1]
            if "--diagnosis-file" in args:
                self.assertEqual(task, "troubleshooter")
                continue
            self.assertIn("--model", args)
            self.assertIn("--all", args)
            if "replay" not in args:
                self.assertIn("--verify-timeout", args)
            self.assertNotIn("${input:instanceId}", args)
            combinations.add((task, args[args.index("--llm-provider") + 1]))
        self.assertEqual(combinations, {
            (task, provider)
            for task in ("troubleshooter", "fixer")
            for provider in ("openai_subscription", "openlux")
        })

    def test_actual_launch_batch_arguments_run_without_docker_or_llm(self) -> None:
        document = json.loads((REPO_ROOT / ".vscode/launch.json").read_text())
        presets = [config for config in document["configurations"]
                   if config.get("module") == "agents.evaluator.run_case"
                   and "--all" in config["args"] and "replay" not in config["args"]]
        self.assertTrue(presets, "Expected at least one automated batch preset")
        for preset in presets:
            args = preset["args"]
            task = args[args.index("--task") + 1]
            provider = args[args.index("--llm-provider") + 1]
            model = args[args.index("--model") + 1]
            with self.subTest(preset=preset["name"]), tempfile.TemporaryDirectory() as temporary, redirect_stdout(
                StringIO()
            ), patch.dict(os.environ, {
                "OPENLUX_API_KEY": "test-key",
                "OPENLUX_API_URL": "https://example.invalid/v1",
            }, clear=True), patch.object(run_case, "load_repository_env"), patch.object(
                run_case, "run_agent_entrypoint", side_effect=lambda role, main: main()
            ), patch("agents.manager.batch.discover_cases", return_value=(["CA1", "CA14"], [])), patch(
                "agents.builder.validate_case.main", side_effect=[1, 0]
            ) as verify, patch(f"agents.evaluator.{task}.run_case.main", return_value=0) as evaluate, patch(
                "agents.evaluator.run_case.repair_context", return_value={}
            ):
                destination = Path(temporary) / "batch"
                self.assertEqual(run_case.main([*args, "--batch-dir", str(destination)]), 1)
                result = json.loads((destination / "batch_result.json").read_text())
                self.assertEqual(result["experiment"]["provider"], provider)
                self.assertEqual(result["experiment"]["model"], model)
                self.assertEqual(result["counts"], {"verification_failed": 1, "completed": 1})
                self.assertEqual(verify.call_count, 2)
                self.assertEqual(verify.call_args.args[0][-2:], ["--timeout", "120"])
                evaluate.assert_called_once()
                self.assertEqual(evaluate.call_args.args[0][0], "CA14")
                self.assertIn(model, evaluate.call_args.args[0])
                self.assertNotIn("--all", evaluate.call_args.args[0])

    def test_fixer_records_model_and_replays_patch(self) -> None:
        config = OpenHandsConfig(model="openai/test-model", provider="openlux")
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(StringIO()), patch.object(
            fixer, "load_repository_env"
        ), patch.object(fixer, "ContainerRuntime") as runtime, patch.object(
            fixer, "_openhands_config", return_value=config
        ), patch.object(fixer, "_run_openhands_agent", return_value="Repaired.") as agent, patch.object(
            fixer, "_export_prediction_patch", return_value="test patch"
        ), patch.object(
            fixer, "_evaluate_fixer_patch", return_value={"exit_code": 0}
        ) as evaluate:
            runtime.return_value.__enter__.return_value.container_name = "test-container"
            run_dir = Path(directory) / "run"
            code = fixer.main(["CA1", "--run-dir", str(run_dir)])
            record = json.loads((run_dir / "result.json").read_text())
            self.assertEqual(code, 0)
            self.assertEqual(record["agent_role"], "fixer")
            self.assertEqual(record["experiment"]["model"], "openai/test-model")
            self.assertEqual(record["experiment"]["provider"], "openlux")
            self.assertIs(agent.call_args.args[-1], config)
            self.assertTrue(evaluate.call_args.kwargs["has_patch"])


if __name__ == "__main__":
    unittest.main()
