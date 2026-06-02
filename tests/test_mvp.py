from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from benchmark.case import CaseDefinition, build_prediction_patch


REPO_ROOT = Path(__file__).resolve().parents[1]


class CaseDefinitionTest(unittest.TestCase):
    def test_ca35_loads_private_policy(self) -> None:
        case = CaseDefinition.load(REPO_ROOT / "instances" / "CA35")

        self.assertEqual(case.instance_id, "CA35")
        self.assertEqual(case.image_name, "ca35:latest")
        self.assertEqual(case.allowed_modified_files, ("etc/mysql/my.cnf",))
        self.assertIn("mysql -N -B -e 'SELECT 1;'", case.read_public_problem())

    def test_prediction_patch_allows_arbitrary_valid_config_text(self) -> None:
        case = CaseDefinition.load(REPO_ROOT / "instances" / "CA35")
        with tempfile.TemporaryDirectory() as temporary_dir:
            exported = Path(temporary_dir) / "etc/mysql/my.cnf"
            exported.parent.mkdir(parents=True)
            baseline = case.baseline_path("etc/mysql/my.cnf").read_text()
            exported.write_text(
                baseline.replace("password = CA35'='", 'password = \"CA35\\'=\\'\"')
            )

            patch = build_prediction_patch(case, {"etc/mysql/my.cnf": exported})

        self.assertIn("--- a/etc/mysql/my.cnf", patch)
        self.assertIn("+++ b/etc/mysql/my.cnf", patch)
        self.assertIn("-password = CA35'='", patch)
        self.assertIn("+password = \"CA35'='\"", patch)


if __name__ == "__main__":
    unittest.main()

