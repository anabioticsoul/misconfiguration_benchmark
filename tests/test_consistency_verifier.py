import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from agents.verifier.review import DIMENSIONS, add_evidence, parse_review
from agents.verifier import run_case
from agents.builder import run_case as builder
from agents.manager import OpenHandsConfig


class ConsistencyVerifierTest(unittest.TestCase):
    def response(self, status="pass"):
        return json.dumps({"checks": {key: {"status": status, "reason": "test evidence",
                                             "evidence": ["source/description.md"]}
                                      for key in DIMENSIONS}})

    def test_verdicts_references_and_truncation(self):
        evidence = {}
        add_evidence(evidence, "source/description.md", "source")
        self.assertEqual(parse_review(self.response(), evidence)["verdict"], "consistent")
        self.assertEqual(parse_review(self.response("fail"), evidence)["verdict"], "inconsistent")
        self.assertEqual(parse_review(self.response("uncertain"), evidence)["verdict"], "needs_review")
        with self.assertRaises(ValueError):
            parse_review(self.response(), {})
        with self.assertRaises(ValueError):
            parse_review('{"checks": {}}', evidence)
        evidence["source/description.md"]["truncated"] = True
        self.assertEqual(parse_review(self.response(), evidence)["verdict"], "needs_review")

    def test_model_cannot_override_failed_validation(self):
        for passed in (False, True):
            with self.subTest(passed=passed), tempfile.TemporaryDirectory() as directory, \
                redirect_stdout(io.StringIO()), \
                patch.object(run_case, "load_repository_env"), \
                patch.object(run_case, "configure_agent_failure_context"), \
                patch.object(run_case.OpenHandsConfig, "from_environment", return_value=OpenHandsConfig(model="test")), \
                patch.object(run_case, "CaseDefinition"), \
                patch.object(run_case, "ContainerRuntime"), \
                patch.object(run_case, "InstanceBuildDefinition"), \
                patch.object(run_case, "DockerInstanceBuilder") as docker, \
                patch.object(run_case, "collect_evidence", return_value={"source/description.md": {"text": "source", "truncated": False}}), \
                patch.object(run_case, "review_with_agent", return_value=self.response()):
                run_case.CaseDefinition.load.return_value.instance_id = "CA1"
                docker.return_value.validate.return_value = {"success": passed}
                destination = Path(directory) / "review"
                code = run_case.main(["CA1", "--run-dir", str(destination)])
                result = json.loads((destination / "result.json").read_text())
                self.assertEqual(code, 0 if passed else 1)
                self.assertEqual(result["success"], passed)
                self.assertEqual(result["verification_kind"], "consistency_review")
                self.assertTrue((destination / "evidence.json").is_file())

    def test_validate_only_never_generates_or_builds(self):
        with patch.object(builder, "load_repository_env"), \
            patch("agents.builder.validate_case.main", return_value=0) as validate, \
            patch.object(builder, "_run_openhands_builder") as generate, \
            patch.object(builder, "DockerInstanceBuilder") as docker:
            self.assertEqual(builder.main(["CA1", "--validate-only"]), 0)
            validate.assert_called_once_with(["CA1", "--timeout", "180"])
            generate.assert_not_called()
            docker.assert_not_called()

    def test_read_tool_cannot_escape_evidence(self):
        from agents.verifier.openhands_tools import ReviewEvidenceAction, ReviewEvidenceExecutor
        executor = ReviewEvidenceExecutor({"case/instance.json": {"text": "fixture"}})
        denied = executor(ReviewEvidenceAction(path="../../.env"))
        self.assertTrue(denied.is_error)
        self.assertFalse(executor(ReviewEvidenceAction(path="case/instance.json")).is_error)


if __name__ == "__main__":
    unittest.main()
