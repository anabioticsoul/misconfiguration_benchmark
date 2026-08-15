from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from agents.manager.evaluation import evaluate_prediction


class EvaluationTest(unittest.TestCase):
    def test_evaluator_inherits_the_image_platform(self) -> None:
        case = SimpleNamespace(
            image_name="example:latest",
            evaluator=Path("/tmp/eval_patch.sh"),
        )
        inspect_result = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="linux/amd64\n",
            stderr="",
        )
        evaluate_result = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="passed\n",
            stderr="",
        )

        with patch(
            "agents.manager.evaluation.subprocess.run",
            side_effect=[inspect_result, evaluate_result],
        ) as run:
            result = evaluate_prediction(case, Path("/tmp/prediction.diff"))

        evaluator_environment = run.call_args_list[1].kwargs["env"]
        self.assertEqual(
            evaluator_environment["DOCKER_DEFAULT_PLATFORM"],
            "linux/amd64",
        )
        self.assertEqual(result["exit_code"], 0)

    def test_missing_image_platform_keeps_the_environment_usable(self) -> None:
        case = SimpleNamespace(
            image_name="missing:latest",
            evaluator=Path("/tmp/eval_patch.sh"),
        )
        missing_result = subprocess.CompletedProcess(
            args=[],
            returncode=1,
            stdout="",
            stderr="missing",
        )
        evaluate_result = subprocess.CompletedProcess(
            args=[],
            returncode=1,
            stdout="",
            stderr="failed",
        )

        with patch.dict(os.environ, {}, clear=True):
            with patch(
                "agents.manager.evaluation.subprocess.run",
                side_effect=[missing_result, evaluate_result],
            ) as run:
                evaluate_prediction(case, Path("/tmp/prediction.diff"))

        evaluator_environment = run.call_args_list[1].kwargs["env"]
        self.assertNotIn("DOCKER_DEFAULT_PLATFORM", evaluator_environment)


if __name__ == "__main__":
    unittest.main()
