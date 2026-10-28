from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from agents.builder.prompts import render_builder_prompt
from agents.builder.run_case import (
    _record_ineligible_result,
    _preflight_generated_workspace,
    _sync_description_from_assets,
)
from agents.manager.build import InstanceBuildDefinition
from agents.manager import TAXONOMY_PATH
from agents.manager.case import CaseDefinition
from agents.manager.paths import instance_dir
from agents.manager.workspace import WorkspaceFiles


REPO_ROOT = Path(__file__).resolve().parents[1]


class BuilderTest(unittest.TestCase):
    def test_streamed_harness_requires_interactive_stdin(self) -> None:
        for flags, accepted in (("", False), ("-t", False), ("-i", True),
                                ("-it", True), ("--interactive", True)):
            with self.subTest(flags=flags), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root / "harness").mkdir()
                (root / "harness/eval_patch.sh").write_text(
                    '#!/usr/bin/env bash\nset -euo pipefail\n'
                    f'docker exec {flags} "$container" bash -s < "$script_dir/f2p.sh"\n'
                )
                if accepted:
                    _preflight_generated_workspace(root)
                else:
                    with self.assertRaisesRegex(ValueError, "requires -i"):
                        _preflight_generated_workspace(root)

    def setUp(self) -> None:
        self.case = CaseDefinition.load(instance_dir(REPO_ROOT, "CA35"))

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
        self.assertIn(
            "USER root",
            definition.base_dockerfile_template.read_text(),
        )
        self.assertIn(
            "{% if source_user %}",
            definition.instance_dockerfile_template.read_text(),
        )

    def test_builder_syncs_asset_description_and_creates_case_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            root = Path(temporary_dir)
            assets_root = root / "assets"
            source = assets_root / "CB" / "CB999.md"
            source.parent.mkdir(parents=True)
            source.write_text("# CB999\n\nSource description.\n", encoding="utf-8")
            case_dir = instance_dir(root, "CB999")

            description_path = _sync_description_from_assets(
                "CB999",
                case_dir,
                assets_root,
            )

            self.assertEqual(
                description_path,
                case_dir / "meta" / "description.md",
            )
            self.assertEqual(
                description_path.read_text(encoding="utf-8"),
                "# CB999\n\nSource description.\n",
            )

    def test_builder_does_not_overwrite_existing_description(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            root = Path(temporary_dir)
            case_dir = instance_dir(root, "CA999")
            description_path = case_dir / "meta" / "description.md"
            description_path.parent.mkdir(parents=True)
            description_path.write_text("Existing description.\n", encoding="utf-8")
            source = root / "assets" / "CA" / "CA999.md"
            source.parent.mkdir(parents=True)
            source.write_text("Asset description.\n", encoding="utf-8")

            synced_path = _sync_description_from_assets(
                "CA999",
                case_dir,
                root / "assets",
            )

            self.assertEqual(synced_path, description_path)
            self.assertEqual(
                synced_path.read_text(encoding="utf-8"),
                "Existing description.\n",
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

    def test_builder_records_explicit_ineligible_response_without_failure(self) -> None:
        result: dict[str, object] = {"success": False}

        handled = _record_ineligible_result(
            result,
            "MISCONFIGBENCH_INELIGIBLE: The accepted answer requires runtime cleanup.",
        )

        self.assertTrue(handled)
        self.assertTrue(result["success"])
        self.assertEqual(result["outcome"], "ineligible")
        self.assertEqual(
            result["ineligible_reason"],
            "The accepted answer requires runtime cleanup.",
        )

    def test_builder_ignores_ordinary_agent_response(self) -> None:
        self.assertFalse(
            _record_ineligible_result({}, "Implemented a valid instance.")
        )

    def test_builder_prompt_prohibits_inventing_repairs_for_non_actionable_sources(
        self,
    ) -> None:
        prompt = render_builder_prompt(
            REPO_ROOT,
            "CB110",
            "# Source\n\n## Accepted Answer\nThe configuration already works.",
            TAXONOMY_PATH.read_text(),
            "- nginx:1.25.5",
        )

        self.assertIn("Accepted Answer", prompt)
        self.assertIn("Do not invent a different symptom", prompt)
        self.assertIn("not an actionable `misconfig_troubleshooting` task", prompt)

    def test_ca14_generated_contract_loads(self) -> None:
        case = CaseDefinition.load(instance_dir(REPO_ROOT, "CA14"))
        definition = InstanceBuildDefinition.load(case)

        self.assertEqual(case.instance_id, "CA14")
        self.assertEqual(definition.output_image, "ca14:latest")
        self.assertTrue(definition.base_script)
        self.assertTrue(
            (definition.context_dir / "fault-overlay/etc/mysql/my.cnf").is_file()
        )

    def test_shell_preflight_rejects_sigpipe_prone_pipefail_pipeline(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            case_dir = Path(temporary_dir)
            harness = case_dir / "harness"
            harness.mkdir()
            (harness / "repro.sh").write_text(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                "php -i | awk '/html_errors/{print; exit}'\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "early-exiting"):
                _preflight_generated_workspace(case_dir)

    def test_shell_preflight_accepts_direct_runtime_query(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            case_dir = Path(temporary_dir)
            harness = case_dir / "harness"
            harness.mkdir()
            (harness / "repro.sh").write_text(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                "php -r 'echo ini_get(\"html_errors\");'\n",
                encoding="utf-8",
            )

            _preflight_generated_workspace(case_dir)

    def test_shell_preflight_rejects_baseline_commit_message_as_revision(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            case_dir = Path(temporary_dir)
            harness = case_dir / "harness"
            harness.mkdir()
            (harness / "eval_patch.sh").write_text(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                "git commit -qm baseline\n"
                "git diff --name-only baseline\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "not a Git revision"):
                _preflight_generated_workspace(case_dir)

    def test_shell_preflight_rejects_relative_evaluator_harness_path(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            case_dir = Path(temporary_dir)
            harness = case_dir / "harness"
            harness.mkdir()
            (harness / "eval_patch.sh").write_text(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                "docker exec test bash -s < harness/f2p.sh\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "relative host path"):
                _preflight_generated_workspace(case_dir)

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
