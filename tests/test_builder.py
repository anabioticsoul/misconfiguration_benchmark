from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from agents.builder.prompts import render_builder_prompt
from agents.manager.build import InstanceBuildDefinition
from agents.manager import TAXONOMY_PATH
from agents.manager.case import CaseDefinition
from agents.manager.workspace import WorkspaceFiles


REPO_ROOT = Path(__file__).resolve().parents[1]


class BuilderTest(unittest.TestCase):
    def setUp(self) -> None:
        self.case = CaseDefinition.load(REPO_ROOT / "instances" / "CA35")

    def test_ca35_builder_uses_separate_base_and_instance_images(self) -> None:
        definition = InstanceBuildDefinition.load(self.case)

        self.assertEqual(
            definition.source_image, "misconfigbench/mysql-8.0.27:base"
        )
        self.assertEqual(definition.base_image, "ca35:base")
        self.assertEqual(definition.output_image, self.case.image_name)
        self.assertNotEqual(definition.base_image, definition.output_image)
        self.assertEqual(
            definition.base_dockerfile_template,
            REPO_ROOT / "templates/builder/Dockerfile.base.j2",
        )
        self.assertIn(
            "COPY base-overlay/",
            definition.base_dockerfile_template.read_text(),
        )
        self.assertIn(
            "COPY fault-overlay/",
            definition.instance_dockerfile_template.read_text(),
        )

    def test_ca35_build_context_injects_only_the_password_fault(self) -> None:
        definition = InstanceBuildDefinition.load(self.case)
        fixed = (
            definition.context_dir / "base-overlay/etc/mysql/my.cnf"
        ).read_text()
        faulty = (
            definition.context_dir / "fault-overlay/etc/mysql/my.cnf"
        ).read_text()

        self.assertEqual(
            fixed.replace('password = "ca35\\\\spass"', "password = ca35\\spass"),
            faulty,
        )

    def test_builder_prompt_uses_description_as_case_specific_input(self) -> None:
        prompt = render_builder_prompt(
            REPO_ROOT,
            self.case.instance_id,
            self.case.read_public_problem(),
            TAXONOMY_PATH.read_text(),
            "- misconfigbench/mysql-8.0.27:base",
        )

        self.assertIn("MySQL Client Authentication Failure", prompt)
        self.assertIn("description below is the only case-specific", prompt)
        self.assertIn("misconfigbench/mysql-8.0.27:base", prompt)
        self.assertNotIn("CA35 Private Build Requirements", prompt)
        self.assertIn('"private_metadata": "meta/metadata.json"', prompt)
        self.assertIn('"ready_check": "<shell readiness check>"', prompt)
        self.assertIn(
            "eval_patch.sh <prediction-patch> [image-name]",
            prompt,
        )
        self.assertIn('patch_file="$(cd "$(dirname "$1")"', prompt)
        self.assertIn("real failing software command", prompt)
        self.assertIn("Every F2P script must fail", prompt)

    def test_ca14_generated_contract_loads(self) -> None:
        case = CaseDefinition.load(REPO_ROOT / "instances" / "CA14")
        definition = InstanceBuildDefinition.load(case)

        self.assertEqual(case.instance_id, "CA14")
        self.assertEqual(definition.output_image, "ca14:latest")
        self.assertTrue(definition.base_script)
        self.assertTrue(
            (definition.context_dir / "fault-overlay/etc/mysql/my.cnf").is_file()
        )

    def test_workspace_rejects_path_escape(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            workspace = WorkspaceFiles(Path(temporary_dir))
            with self.assertRaises(ValueError):
                workspace.write("../outside", "not allowed")

    def test_build_spec_rejects_context_escape(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            workspace_root = Path(temporary_dir)
            shutil.copytree(self.case.case_dir / "build", workspace_root / "build")
            spec_path = workspace_root / "build/build.json"
            spec = json.loads(spec_path.read_text())
            spec["context_dir"] = "../outside"
            spec_path.write_text(json.dumps(spec), encoding="utf-8")

            with self.assertRaises(ValueError):
                InstanceBuildDefinition.load(self.case, workspace_root)

    def test_build_spec_rejects_source_base_self_reference(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            workspace_root = Path(temporary_dir)
            shutil.copytree(self.case.case_dir / "build", workspace_root / "build")
            spec_path = workspace_root / "build/build.json"
            spec = json.loads(spec_path.read_text())
            spec["images"]["source"] = spec["images"]["base"]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")

            with self.assertRaisesRegex(
                ValueError, "source image must not equal"
            ):
                InstanceBuildDefinition.load(self.case, workspace_root)

    def test_build_spec_rejects_another_case_as_source_image(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            workspace_root = Path(temporary_dir)
            shutil.copytree(self.case.case_dir / "build", workspace_root / "build")
            spec_path = workspace_root / "build/build.json"
            spec = json.loads(spec_path.read_text())
            spec["images"]["source"] = "cb116:base"
            spec_path.write_text(json.dumps(spec), encoding="utf-8")

            with self.assertRaisesRegex(
                ValueError, "another benchmark case image"
            ):
                InstanceBuildDefinition.load(self.case, workspace_root)

    def test_build_spec_rejects_mismatched_purpose_built_image(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            workspace_root = Path(temporary_dir)
            shutil.copytree(self.case.case_dir / "build", workspace_root / "build")
            spec_path = workspace_root / "build/build.json"
            spec = json.loads(spec_path.read_text())
            spec["images"]["source"] = "misconfigbench/nginx-1.24:base"
            spec_path.write_text(json.dumps(spec), encoding="utf-8")

            with self.assertRaisesRegex(
                ValueError, "does not match target software"
            ):
                InstanceBuildDefinition.load(self.case, workspace_root)

    def test_build_spec_rejects_mismatched_official_software_image(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            workspace_root = Path(temporary_dir)
            shutil.copytree(self.case.case_dir / "build", workspace_root / "build")
            spec_path = workspace_root / "build/build.json"
            spec = json.loads(spec_path.read_text())
            spec["images"]["source"] = "nginx:1.18.0"
            spec_path.write_text(json.dumps(spec), encoding="utf-8")

            with self.assertRaisesRegex(
                ValueError, "Official software source image"
            ):
                InstanceBuildDefinition.load(self.case, workspace_root)


if __name__ == "__main__":
    unittest.main()
