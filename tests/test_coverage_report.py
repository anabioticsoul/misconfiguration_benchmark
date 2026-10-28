import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.report_coverage import collect, render, validation_records


class CoverageReportTest(unittest.TestCase):
    def test_latest_failure_overrides_success_and_ignores_fixer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for index, (role, passed) in enumerate([
                ("verifier", True), ("verifier", False), ("fixer", True)
            ], start=1):
                path = root / "runs" / str(index)
                path.mkdir(parents=True)
                (path / "result.json").write_text(json.dumps({
                    "instance_id": "CA1", "agent_role": role,
                    "finished_at": f"2026-10-0{index}T00:00:00+00:00",
                    "success": passed, "reproduction": {"exit_code": 0},
                    "reference_evaluation": {"exit_code": 0 if passed else 1}
                }))
            records = validation_records(root)
            self.assertFalse(records["CA1"]["passed"])
            self.assertEqual(records["CA1"]["source"], "runs/2/result.json")

    def test_manual_validation_and_dry_run(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "runs/20261016-ca41-repair-validation"
            path.mkdir(parents=True)
            validation = {"success": True, "reproduction": {"exit_code": 0},
                          "reference_evaluation": {"exit_code": 0}}
            (path / "validation.json").write_text(json.dumps(validation))
            (path / "result.json").write_text(json.dumps({
                "instance_id": "CA99", "agent_role": "builder", "dry_run": True,
                "validation": validation
            }))
            records = validation_records(root)
            self.assertEqual(set(records), {"CA41"})
            self.assertTrue(records["CA41"]["passed"])

    def test_metadata_not_case_prefix_controls_category(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "standards").mkdir()
            (root / "standards/taxonomy.json").write_text(json.dumps({
                "schema_version": "1.0", "types": [{"id": "CA", "name": "Constraints",
                    "subtypes": [{"id": "CA-3", "name": "Misplaced"},
                                 {"id": "CA-4", "name": "Duplicate"}]}]
            }))
            meta = root / "instances/CD/CD158/meta"
            meta.mkdir(parents=True)
            (meta / "metadata.json").write_text(json.dumps({"private_oracle": {
                "classification": {"category_id": "CA-3"}}}))
            with patch("scripts.report_coverage.discover_cases", return_value=(["CD158"], [])):
                report = collect(root)
            self.assertEqual(report["rows"][0]["unknown"], ["CD158"])
            self.assertEqual(report["rows"][1]["complete"], [])
            self.assertIn("CA-4：Duplicate", render(report))


if __name__ == "__main__":
    unittest.main()
