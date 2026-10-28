from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from agents.evaluator.troubleshooter.run_case import main as run_diagnosis_evaluator
from agents.evaluator.troubleshooter.prompts import render_diagnosis_prompt
from agents.evaluator.troubleshooter.scoring import (
    aggregate_diagnosis_results,
    parse_diagnosis_response,
    score_diagnosis,
)
from agents.manager import TAXONOMY_PATH
from agents.manager.case import CaseDefinition
from agents.manager.paths import instance_dir


REPO_ROOT = Path(__file__).resolve().parents[1]


class DiagnosisEvaluatorTest(unittest.TestCase):
    def setUp(self) -> None:
        self.case = CaseDefinition.load(instance_dir(REPO_ROOT, "CA1"))
        self.response = """```json
{
  "classification": {"type_id": "CA", "subtype_id": "CA-1"},
  "ranked_locations": [
    {
      "component": "MySQL",
      "path": "/etc/mysql/conf.d/fault.cnf",
      "section": "mysqld",
      "option": "query_cache_size-128M"
    }
  ]
}
```"""

    def test_exact_prediction_scores_all_primary_metrics(self) -> None:
        result = score_diagnosis(self.case, parse_diagnosis_response(self.response))

        self.assertTrue(result["classification"]["type_exact"])
        self.assertTrue(result["classification"]["subtype_exact"])
        self.assertTrue(result["localization"]["component"]["hit_at_1"])
        self.assertTrue(
            result["localization"]["configuration_target"]["hit_at_1"]
        )
        self.assertEqual(result["localization"]["configuration_target"]["mrr"], 1.0)
        self.assertTrue(result["joint"]["joint_at_1"])

    def test_diagnosis_prompt_exposes_only_public_case_information(self) -> None:
        prompt = render_diagnosis_prompt(
            self.case,
            TAXONOMY_PATH.read_text(encoding="utf-8"),
        )

        self.assertIn("CA-1", prompt)
        self.assertIn("MySQL fails to start", prompt)
        self.assertNotIn("/etc/mysql/conf.d/fault.cnf", prompt)
        self.assertNotIn("gold_patch", prompt)

    def test_ranked_location_receives_mrr_and_hit_at_k_credit(self) -> None:
        prediction = parse_diagnosis_response(
            """{
              "classification": {"type_id": "CA", "subtype_id": "CA-2"},
              "ranked_locations": [
                {"component": "mysql", "path": "/wrong.cnf", "section": "mysqld", "option": "x"},
                {"component": "mysql", "path": "/etc/mysql/conf.d/fault.cnf", "section": "mysqld", "option": "query_cache_size-128M"}
              ]
            }"""
        )
        result = score_diagnosis(self.case, prediction)

        target = result["localization"]["configuration_target"]
        self.assertFalse(result["classification"]["subtype_exact"])
        self.assertFalse(target["hit_at_1"])
        self.assertTrue(target["hit_at_3"])
        self.assertEqual(target["mrr"], 0.5)
        self.assertFalse(result["joint"]["joint_at_3"])

    def test_invalid_response_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "valid JSON"):
            parse_diagnosis_response("The likely cause is a typo.")

    def test_invalid_diagnosis_is_included_as_a_zero_score(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            root = Path(temporary_dir)
            input_path = root / "invalid.txt"
            run_dir = root / "run"
            input_path.write_text("I suspect a configuration issue.", encoding="utf-8")

            exit_code = run_diagnosis_evaluator(
                ["CA1", "--diagnosis-file", str(input_path), "--run-dir", str(run_dir)]
            )
            record = json.loads((run_dir / "diagnosis_result.json").read_text())

        self.assertEqual(exit_code, 0)
        self.assertFalse(record["diagnosis_valid"])
        self.assertFalse(record["result"]["classification"]["subtype_exact"])
        self.assertFalse(record["result"]["joint"]["joint_at_1"])

    def test_report_uses_macro_f1_and_rank_metrics(self) -> None:
        exact = score_diagnosis(self.case, parse_diagnosis_response(self.response))
        incorrect = score_diagnosis(
            self.case,
            parse_diagnosis_response(
                """{
                  "classification": {"type_id": "CB", "subtype_id": "CB-1"},
                  "ranked_locations": []
                }"""
            ),
        )

        report = aggregate_diagnosis_results([exact, incorrect], TAXONOMY_PATH)

        self.assertEqual(report["evaluated_cases"], 2)
        self.assertEqual(report["root_cause_subtype"]["accuracy"], 0.5)
        self.assertEqual(
            report["configuration_target_localization"]["hit_at_1"], 0.5
        )
        self.assertEqual(report["joint_diagnosis"]["joint_at_1"], 0.5)

    def test_offline_entrypoint_scores_a_diagnosis_without_docker(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            root = Path(temporary_dir)
            input_path = root / "diagnosis.json"
            run_dir = root / "run"
            input_path.write_text(self.response, encoding="utf-8")

            exit_code = run_diagnosis_evaluator(
                [
                    "CA1",
                    "--diagnosis-file",
                    str(input_path),
                    "--run-dir",
                    str(run_dir),
                ]
            )
            record = json.loads((run_dir / "diagnosis_result.json").read_text())

        self.assertEqual(exit_code, 0)
        self.assertTrue(record["diagnosis_valid"])
        self.assertTrue(record["result"]["joint"]["joint_at_1"])


if __name__ == "__main__":
    unittest.main()
