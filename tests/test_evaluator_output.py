from __future__ import annotations

import json
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

from agents.evaluator.output import evaluation_run_dir, experiment_identity
from agents.evaluator.troubleshooter import run_case
from agents.evaluator.troubleshooter.report import grouped_report
from agents.evaluator.troubleshooter.scoring import DiagnosisPrediction, score_diagnosis
from agents.manager import CaseDefinition, OpenHandsConfig
from agents.manager.paths import instance_dir


REPO_ROOT = Path(__file__).resolve().parents[1]


class EvaluatorOutputTest(unittest.TestCase):
    def test_paths_separate_provider_and_model(self) -> None:
        root = Path("/tmp/benchmark")
        paths = []
        for provider, model in (
            ("openlux", "model-a"), ("openlux", "model-b"),
            ("openai_subscription", "model-a"),
        ):
            identity = experiment_identity(OpenHandsConfig(model=model, provider=provider))
            path = evaluation_run_dir(root, "fixer", "CA35", identity)
            self.assertEqual(path.parent, root / "runs" / "fixer" / provider / model)
            self.assertTrue(path.name.endswith("-ca35"))
            paths.append(path.parent)
        self.assertEqual(len(set(paths)), 3)

    def test_model_slashes_and_traversal_are_safe_and_distinct(self) -> None:
        parents = []
        for model in ("openai/model", "openai-model", "../../model", "/absolute/model"):
            identity = experiment_identity(OpenHandsConfig(model=model))
            path = evaluation_run_dir(Path("/tmp/bench"), "fixer", "CA1", identity)
            self.assertEqual(path.parent.parent, Path("/tmp/bench/runs/fixer/openai_subscription"))
            self.assertEqual(identity["model"], model)
            parents.append(path.parent)
        self.assertEqual(len(set(parents)), 4)

    def test_explicit_run_directory_is_unchanged(self) -> None:
        experiment = experiment_identity(None, mode="manual")
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "custom"
            self.assertEqual(
                evaluation_run_dir(REPO_ROOT, "fixer", "CA1", experiment, str(target)),
                target.resolve(),
            )

    def test_offline_output_has_no_inferred_model_or_credentials(self) -> None:
        with tempfile.TemporaryDirectory() as temporary, redirect_stdout(StringIO()), patch.object(
            run_case, "load_repository_env"
        ), patch.object(run_case, "_openhands_config") as config:
            source = Path(temporary) / "diagnosis.json"
            source.write_text('{"classification": {}, "ranked_locations": []}')
            destination = Path(temporary) / "run"
            self.assertEqual(run_case.main([
                "CA1", "--diagnosis-file", str(source), "--run-dir", str(destination),
                "--model", "should-not-be-attributed",
            ]), 0)
            config.assert_not_called()
            record = json.loads((destination / "diagnosis_result.json").read_text())
            self.assertEqual(record["experiment"], {
                "mode": "offline", "provider": "offline", "model": "unknown",
            })

    def test_report_does_not_mix_models_providers_or_budgets(self) -> None:
        case = CaseDefinition.load(instance_dir(REPO_ROOT, "CA1"))
        scored = score_diagnosis(case, DiagnosisPrediction(None, None, ()))
        identities = [
            experiment_identity(OpenHandsConfig(model="a", provider="openlux")),
            experiment_identity(OpenHandsConfig(model="b", provider="openlux")),
            experiment_identity(OpenHandsConfig(model="a", provider="openai_subscription")),
            experiment_identity(OpenHandsConfig(model="a", provider="openlux", max_iterations=1)),
        ]
        documents = [{"experiment": identity, "result": scored} for identity in identities]
        documents.extend([
            {"experiment": identities[0], "error": "connection failed"},
            {"experiment": identities[0], "result": scored},
            {"result": scored},
        ])
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for index, document in enumerate(documents):
                directory = root / str(index)
                directory.mkdir()
                (directory / "diagnosis_result.json").write_text(json.dumps(document))
            report = grouped_report(root)
        self.assertEqual(len(report["groups"]), 5)
        group = next(group for group in report["groups"] if group["experiment"] == identities[0])
        self.assertEqual(group["total_runs"], 3)
        self.assertEqual(group["scored_runs"], 2)
        self.assertEqual(group["unscored_runs"], 1)
        self.assertEqual(group["unique_scored_cases"], 1)
        self.assertEqual(group["metrics"]["evaluated_cases"], 2)


if __name__ == "__main__":
    unittest.main()
