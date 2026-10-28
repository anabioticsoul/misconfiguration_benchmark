from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from dataclasses import replace
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

from agents.evaluator.oracles import MissingOracle, case_provenance, digest, repair_context
from agents.evaluator.fixer.prompts import render_case_prompt
from agents.evaluator.fixer import run_case as fixer
from agents.evaluator.troubleshooter import run_case as diagnosis
from agents.evaluator.troubleshooter.evidence import ObservationLedger, audit_evidence, load_observations
from agents.evaluator.troubleshooter.evidence_pack import load_pack, select_observations, public_observations
from agents.evaluator.troubleshooter.openhands_tools import DiagnosticTerminalAction, DiagnosticTerminalExecutor
from agents.evaluator.report import group_identity, grouped_repair_report
from agents.evaluator.report import paired_comparisons
from agents.evaluator import run_case as evaluator
from agents.manager import CaseDefinition, OpenHandsConfig
from agents.manager.batch import run_case_batch
from agents.manager.evaluation import evaluate_prediction
from agents.manager.paths import instance_dir


ROOT = Path(__file__).resolve().parents[1]


def pack_fixture():
    records = [
        {"id": "obs-0001", "command": "cat config", "text": "bad-option", "exit_code": 0},
        {"id": "obs-0002", "command": "date", "text": "2026", "exit_code": 0},
        {"id": "obs-0003", "command": "validate", "text": "unknown option", "exit_code": 0},
    ]
    return {"schema_version": 1, "instance_id": "CA1", "review_status": "reviewed",
            "case_sha256": digest(case_provenance(CaseDefinition.load(instance_dir(ROOT, "CA1")), "")["case_files_sha256"]),
            "reviewer": "test-fixture", "source_kind": "synthetic_test", "observations": records,
            "observations_sha256": digest(records), "key_observation_ids": ["obs-0001", "obs-0003"],
            "control_observation_ids": ["obs-0002"], "duplicate_evidence_reviewed": True,
            "description_leakage_reviewed": True, "control_length_reviewed": True,
            "private_solution": "DO_NOT_EXPOSE"}


class ResearchProtocolTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.original = CaseDefinition.load(instance_dir(ROOT, "CA1"))
        self.case = replace(self.original, case_dir=self.root)
        (self.root / "meta").mkdir()
        self.metadata = {"private_oracle": {
            "repair_context": {
                "review_status": "reviewed", "reviewer": "test-fixture", "source_kind": "synthetic_test",
                "component": "mysql", "layer": "parser", "cause": "Invalid assignment syntax.",
                "location": {"path": "/etc/mysql/conf.d/fault.cnf", "section": "mysqld", "gold_patch": "SECRET"},
                "gold_patch": "SECRET", "replacement": "SECRET", "source_url": "SECRET",
            },
            "evidence_oracle": {
                "review_status": "reviewed", "reviewer": "test-fixture", "source_kind": "synthetic_test",
                "facts": [{"id": "f1", "alternatives": [
                    {"command_pattern": "cat config", "output_pattern": "bad-option", "exit_code": 0}]}],
                "sufficient_sets": [["f1"]],
            },
        }}
        self.save_metadata()

    def save_metadata(self):
        (self.root / "meta/metadata.json").write_text(json.dumps(self.metadata))

    def test_oracle_is_whitelisted_and_location_does_not_leak_cause(self):
        hint = repair_context(self.case, "location")
        self.assertNotIn("cause", hint)
        self.assertNotIn("SECRET", json.dumps(hint))
        root = repair_context(self.case, "root_cause")
        self.assertEqual(root["cause"], "Invalid assignment syntax.")
        self.assertNotIn("SECRET", render_case_prompt(self.case, "root_cause"))

    def test_unreviewed_oracle_is_rejected_but_e2e_still_works(self):
        self.metadata["private_oracle"]["repair_context"]["review_status"] = "pending"
        self.save_metadata()
        with self.assertRaises(MissingOracle):
            repair_context(self.case, "root_cause")
        self.assertEqual(repair_context(self.case, "none"), {})

    def test_ledger_records_exact_visible_text_and_tool_error(self):
        ledger = ObservationLedger(self.root / "observations.jsonl")
        runtime = Mock()
        runtime.execute.return_value = SimpleNamespace(exit_code=0, render=lambda: "observed content")
        executor = DiagnosticTerminalExecutor(runtime, ledger)
        observation = executor(DiagnosticTerminalAction(command="cat config"))
        records = load_observations(ledger.path)
        self.assertIn("obs-0001", observation.model_dump_json())
        self.assertEqual(records[0]["text"], "Observation ID: obs-0001\nobserved content")
        runtime.execute.side_effect = RuntimeError("permission denied")
        executor(DiagnosticTerminalAction(command="read log"))
        self.assertIsNone(load_observations(ledger.path)[1]["exit_code"])

    def test_acquisition_requires_actual_successful_observation(self):
        records = pack_fixture()["observations"]
        result = audit_evidence(self.case, {"claims": []}, records)
        self.assertTrue(result["sufficient_evidence_acquired"])
        self.assertEqual(result["first_sufficient_evidence"]["tool_calls"], 1)
        records[0]["exit_code"] = 1
        self.assertFalse(audit_evidence(self.case, {"claims": []}, records)["sufficient_evidence_acquired"])

    def test_citation_validity_is_not_claim_support(self):
        prediction = {"claims": [{"kind": "root_cause", "text": "Wrong conclusion",
                                   "evidence_refs": ["obs-0001", "obs-9999"]}]}
        result = audit_evidence(self.case, prediction, pack_fixture()["observations"])
        self.assertEqual(result["citation_validity"], 0.5)
        self.assertIsNone(result["core_claim_support_rate"])
        self.assertEqual(len(result["missing_claim_kinds"]), 2)

    def test_human_support_review_is_bound_to_exact_artifacts(self):
        records = pack_fixture()["observations"]
        prediction = {"claims": [{"kind": "root_cause", "text": "Invalid syntax", "evidence_refs": ["obs-0001"]}]}
        result = audit_evidence(self.case, prediction, records)
        review = result["review_template"]
        review.update(review_status="reviewed", reviewer="test-fixture",
                      judgments={"root_cause": "supported", "symptom": "missing", "localization": "missing"})
        self.assertAlmostEqual(audit_evidence(self.case, prediction, records, review)["core_claim_support_rate"], 1/3)
        prediction["claims"][0]["text"] = "Changed conclusion"
        with self.assertRaisesRegex(ValueError, "does not match"):
            audit_evidence(self.case, prediction, records, review)

    def test_missing_evidence_oracle_returns_unknown_not_zero(self):
        self.metadata["private_oracle"].pop("evidence_oracle")
        self.save_metadata()
        result = audit_evidence(self.case, {"claims": []}, [])
        self.assertEqual(result["acquisition_status"], "not_annotated")
        self.assertIsNone(result["sufficient_evidence_acquired"])
        self.assertIsNone(result["citation_validity"])

    def test_all_replay_conditions_and_public_projection(self):
        pack = pack_fixture()
        path = self.root / "pack.json"
        path.write_text(json.dumps(pack))
        checked = load_pack(path, "CA1")
        expected = {"full": 3, "key_only": 2, "key_removed": 1, "matched_control": 2, "description_only": 0}
        for condition, count in expected.items():
            self.assertEqual(len(select_observations(checked, condition)), count)
        self.assertNotIn("DO_NOT_EXPOSE", json.dumps(public_observations(checked["observations"])))

    def test_replay_rejects_wrong_case_unreviewed_and_changed_pack(self):
        path = self.root / "pack.json"
        for field, value in (("instance_id", "CA14"), ("review_status", "pending"),
                             ("observations_sha256", "wrong"), ("duplicate_evidence_reviewed", False)):
            pack = pack_fixture()
            pack[field] = value
            path.write_text(json.dumps(pack))
            with self.subTest(field=field), self.assertRaises(ValueError):
                load_pack(path, "CA1")

    def test_replay_runner_uses_no_environment_tools(self):
        path = self.root / "pack.json"
        path.write_text(json.dumps(pack_fixture()))
        config = OpenHandsConfig(model="test-model")
        with patch.object(diagnosis, "load_repository_env"), patch.object(
            diagnosis, "_openhands_config", return_value=config
        ), patch.object(diagnosis, "ContainerRuntime") as docker, patch.object(
            diagnosis, "run_openhands_agent", return_value='{"classification": {}, "ranked_locations": [], "claims": []}'
        ) as agent, redirect_stdout(StringIO()):
            destination = self.root / "replay"
            self.assertEqual(diagnosis.main(["CA1", "--evidence-mode", "replay", "--evidence-pack", str(path),
                "--evidence-condition", "key_removed", "--run-dir", str(destination)]), 0)
            docker.assert_not_called()
            self.assertEqual(agent.call_args.args[1], [])
            prompt = agent.call_args.args[0]
            self.assertNotIn("bad-option", prompt)
            self.assertNotIn('"id": "obs-0003"', prompt)
            self.assertNotIn("DO_NOT_EXPOSE", prompt)
            self.assertIn("2026", prompt)
            result = json.loads((destination / "diagnosis_result.json").read_text())
            self.assertEqual(result["evidence"]["acquisition_status"], "not_applicable_replay")

    def test_batch_skip_and_replay_without_verifier(self):
        with patch("agents.manager.batch.discover_cases", return_value=(["CA1", "CA14"], [])), redirect_stdout(StringIO()):
            evaluate = Mock(return_value=0)
            code = run_case_batch(ROOT, self.root / "batch", task="troubleshooter", experiment={},
                                  verify=None, evaluate=evaluate, eligibility=lambda cid: "unreviewed" if cid == "CA1" else None)
            self.assertEqual(code, 0)
            evaluate.assert_called_once()
            self.assertEqual(evaluate.call_args.args[0], "CA14")

    def test_old_harness_checks_remain_unknown(self):
        case = SimpleNamespace(image_name="test", evaluator=Path("/tmp/eval.sh"))
        result = subprocess.CompletedProcess([], 0, "", "")
        with patch("agents.manager.evaluation.subprocess.run", return_value=result):
            report = evaluate_prediction(case, Path("/tmp/fix.diff"))
        self.assertEqual(report["exit_code"], 0)
        self.assertIsNone(report["safe_success"])
        self.assertEqual(report["checks"]["f2p"], "not_evaluated")

    def test_structured_harness_failure_overrides_zero_exit(self):
        case = SimpleNamespace(image_name="test", evaluator=Path("/tmp/eval.sh"))

        def run(*args, **kwargs):
            if "env" in kwargs:
                Path(kwargs["env"]["MISCONFIGBENCH_EVALUATION_RESULT"]).write_text(json.dumps({"safety": "fail"}))
            return subprocess.CompletedProcess([], 0, "", "")

        with patch("agents.manager.evaluation.subprocess.run", side_effect=run):
            report = evaluate_prediction(case, Path("/tmp/fix.diff"))
        self.assertEqual(report["exit_code"], 1)

    def test_reports_separate_experiment_conditions(self):
        for index, condition in enumerate(("none", "root_cause")):
            directory = self.root / f"run-{index}"
            directory.mkdir()
            (directory / "result.json").write_text(json.dumps({"instance_id": "CA1", "agent_role": "fixer",
                "experiment": {"model": "m", "provider": "p", "repair_context": condition},
                "success": True, "evaluation": {"exit_code": 0}}))
        self.assertEqual(len(grouped_repair_report(self.root)["groups"]), 2)
        self.assertNotEqual(group_identity({"experiment": {"evidence_condition": "full"}}),
                            group_identity({"experiment": {"evidence_condition": "key_removed"}}))

    def test_repair_missing_oracle_never_starts_container(self):
        with patch.object(fixer, "load_repository_env"), patch.object(
            fixer, "_openhands_config", return_value=OpenHandsConfig(model="test-model")
        ), patch.object(fixer, "ContainerRuntime") as runtime, redirect_stdout(StringIO()):
            destination = self.root / "missing-oracle"
            self.assertEqual(fixer.main(["CA1", "--repair-context", "root_cause", "--run-dir", str(destination)]), 2)
            runtime.assert_not_called()
            self.assertEqual(json.loads((destination / "result.json").read_text())["status"], "skipped_missing_oracle")

    def test_replay_launch_presets_parse_and_skip_docker_for_every_condition(self):
        document = json.loads((ROOT / ".vscode/launch.json").read_text())
        presets = [config for config in document["configurations"] if "replay" in config.get("args", [])]
        self.assertEqual(len(presets), 2)
        pack_dir = self.root / "packs"
        pack_dir.mkdir()
        (pack_dir / "CA1.json").write_text(json.dumps(pack_fixture()))
        for index, preset in enumerate(presets):
            for condition in ("full", "description_only", "key_only", "key_removed", "matched_control"):
                args = [str(pack_dir) if value == "${input:evidencePackDir}" else
                        condition if value == "${input:evidenceCondition}" else value for value in preset["args"]]
                with self.subTest(preset=preset["name"], condition=condition), redirect_stdout(StringIO()), patch.dict(
                    os.environ, {"OPENLUX_API_KEY": "test", "OPENLUX_API_URL": "https://example.invalid"}, clear=True
                ), patch.object(evaluator, "load_repository_env"), patch.object(
                    evaluator, "run_agent_entrypoint", side_effect=lambda role, main: main()
                ), patch("agents.manager.batch.discover_cases", return_value=(["CA1"], [])), patch(
                    "agents.builder.validate_case.main", side_effect=AssertionError("Replay must not verify Docker")
                ), patch.object(diagnosis, "main", return_value=0) as run:
                    destination = self.root / f"batch-{index}-{condition}"
                    self.assertEqual(evaluator.main([*args, "--batch-dir", str(destination)]), 0)
                    self.assertIn(condition, run.call_args.args[0])
                    report = json.loads((destination / "batch_result.json").read_text())
                    self.assertEqual(report["cases"][0]["verification_status"], "not_required")

    def test_paired_report_requires_matching_case_snapshots(self):
        for index, (condition, passed, fingerprint) in enumerate((
            ("none", False, "same"), ("root_cause", True, "same"), ("location", True, "different")
        )):
            destination = self.root / str(index)
            destination.mkdir()
            record = {"agent_role": "fixer", "instance_id": "CA1", "success": passed,
                      "experiment": {"model": "m", "provider": "p", "repair_context": condition},
                      "evaluation": {"exit_code": 0 if passed else 1},
                      "provenance": {"case_files_sha256": {"metadata.json": fingerprint}, "image_reference": "test"}}
            (destination / "result.json").write_text(json.dumps(record))
        comparisons = {item["condition"]: item for item in paired_comparisons(self.root)}
        self.assertEqual(comparisons["root_cause"]["condition_minus_baseline"], 1.0)
        self.assertEqual(comparisons["root_cause"]["paired_cases"], 1)
        self.assertIsNone(comparisons["location"]["condition_minus_baseline"])


if __name__ == "__main__":
    unittest.main()
