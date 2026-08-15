from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from agents.manager.case import (
    CaseDefinition,
    _relative_container_path,
)
from agents.manager.artifacts import build_prediction_patch
from agents.manager import TAXONOMY_PATH
from agents.manager.validation import ContractValidationError, load_case_documents


REPO_ROOT = Path(__file__).resolve().parents[1]


class CaseDefinitionTest(unittest.TestCase):
    def test_taxonomy_category_must_match_instance_prefix(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            case_dir = Path(temporary_dir) / "CA35"
            shutil.copytree(REPO_ROOT / "instances" / "CA35", case_dir)
            metadata_path = case_dir / "meta/metadata.json"
            metadata = json.loads(metadata_path.read_text())
            metadata["private_oracle"]["classification"]["category_id"] = "CD-2"
            metadata_path.write_text(json.dumps(metadata), encoding="utf-8")

            with self.assertRaisesRegex(
                ContractValidationError,
                "CA- subtype family",
            ):
                load_case_documents(case_dir)

    def test_ca35_loads_private_policy(self) -> None:
        case = CaseDefinition.load(REPO_ROOT / "instances" / "CA35")

        self.assertEqual(case.instance_id, "CA35")
        self.assertEqual(case.image_name, "ca35:latest")
        self.assertEqual(case.image_archive_format, "docker_save_tar_gzip")
        self.assertEqual(case.allowed_modified_files, ("etc/mysql/my.cnf",))
        self.assertIn("```bash\nmysql\n```", case.read_public_problem())
        self.assertNotIn("mysql -N -B -e 'SELECT 1;'", case.read_public_problem())
        self.assertEqual(
            case.prompt_protocol["template"],
            "prompts/misconfig_troubleshooting.j2",
        )
        self.assertEqual(
            case.builder_protocol,
            {
                "template": "prompts/instance_builder.j2",
                "spec": "build/build.json",
                "requirements": "build/requirements.md",
            },
        )

    def test_ca35_instance_does_not_describe_fault_injection(self) -> None:
        instance = json.loads(
            (REPO_ROOT / "instances" / "CA35" / "instance.json").read_text()
        )

        self.assertNotIn("bootstrap", instance["runtime"])
        self.assertNotIn("environment", instance["runtime"])
        self.assertNotIn("ready_log_contains", instance["runtime"])

    def test_service_failure_case_can_keep_container_running(self) -> None:
        case = CaseDefinition.load(REPO_ROOT / "instances" / "CB116")

        command = case.docker_create_command("cb116-test")

        self.assertEqual(case.runtime_entrypoint, "/bin/bash")
        self.assertEqual(
            case.runtime_command, ("-lc", "exec tail -f /dev/null")
        )
        self.assertEqual(
            command,
            [
                "docker",
                "create",
                "--name",
                "cb116-test",
                "--entrypoint",
                "/bin/bash",
                "cb116:latest",
                "-lc",
                "exec tail -f /dev/null",
            ],
        )

    def test_ca35_uses_dynamic_baseline_and_behavior_tests(self) -> None:
        instance = json.loads(
            (REPO_ROOT / "instances" / "CA35" / "instance.json").read_text()
        )

        self.assertEqual(
            instance["patch_protocol"]["baseline_source"],
            "fresh_faulty_container",
        )
        self.assertNotIn("baseline_root", instance["patch_protocol"])
        self.assertEqual(instance["task_files"]["public_problem_statement"], "meta/description.md")
        self.assertEqual(instance["task_files"]["private_metadata"], "meta/metadata.json")
        self.assertEqual(instance["task_files"]["reference_patch"], "meta/gold_patch.diff")
        self.assertEqual(instance["task_files"]["fail_to_pass"], ["harness/f2p.sh"])
        self.assertEqual(instance["task_files"]["pass_to_pass"], ["harness/p2p.sh"])
        self.assertEqual(
            instance["host_harness"]["evaluate_prediction"],
            "harness/eval_patch.sh",
        )
        self.assertEqual(
            instance["prompt_protocol"],
            {
                "template": "prompts/misconfig_troubleshooting.j2",
                "case_prompt": "meta/description.md",
            },
        )
        self.assertNotIn("evaluate", instance["evaluator_harness"])

    def test_ca35_classification_uses_taxonomy_id(self) -> None:
        taxonomy = json.loads(TAXONOMY_PATH.read_text())
        metadata = json.loads(
            (REPO_ROOT / "instances" / "CA35" / "meta" / "metadata.json").read_text()
        )
        category_ids = {
            subtype["id"]
            for type_definition in taxonomy["types"]
            for subtype in type_definition["subtypes"]
        }

        classification = metadata["private_oracle"]["classification"]
        self.assertEqual(classification["taxonomy_version"], taxonomy["schema_version"])
        self.assertIn(classification["category_id"], category_ids)
        self.assertEqual(classification["category_id"], "CA-1")

    def test_container_path_traversal_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            _relative_container_path("/etc/../private-oracle")

    def test_invalid_manifest_reports_missing_contract_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            case_dir = Path(temporary_dir)
            (case_dir / "instance.json").write_text(
                json.dumps(
                    {
                        "instance_id": "CB116",
                        "task_files": {
                            "metadata": "meta/metadata.json",
                            "gold_patch": "meta/gold_patch.diff",
                        },
                    }
                ),
                encoding="utf-8",
            )

            with self.assertRaises(ContractValidationError) as raised:
                load_case_documents(
                    case_dir, expected_instance_id="CB116"
                )

        message = str(raised.exception)
        self.assertIn("task_files.private_metadata", message)
        self.assertIn("task_files.reference_patch", message)
        self.assertNotIn("KeyError", message)

    def test_prediction_patch_allows_arbitrary_valid_config_text(self) -> None:
        case = CaseDefinition.load(REPO_ROOT / "instances" / "CA35")
        with tempfile.TemporaryDirectory() as temporary_dir:
            root = Path(temporary_dir)
            baseline = root / "baseline/etc/mysql/my.cnf"
            exported = root / "exported/etc/mysql/my.cnf"
            baseline.parent.mkdir(parents=True)
            exported.parent.mkdir(parents=True)
            baseline_text = "\n".join(
                [
                    "[client]",
                    "user = root",
                    "password = ca35\\spass",
                    "",
                ]
            )
            baseline.write_text(baseline_text, encoding="utf-8")
            exported.write_text(
                baseline_text.replace(
                    "password = ca35\\spass",
                    'password = "ca35\\\\spass"',
                ),
                encoding="utf-8",
            )

            patch = build_prediction_patch(
                case,
                {"etc/mysql/my.cnf": baseline},
                {"etc/mysql/my.cnf": exported},
            )

        self.assertIn("--- a/etc/mysql/my.cnf", patch)
        self.assertIn("+++ b/etc/mysql/my.cnf", patch)
        self.assertIn("-password = ca35\\spass", patch)
        self.assertIn('+password = "ca35\\\\spass"', patch)


if __name__ == "__main__":
    unittest.main()
