from __future__ import annotations

import unittest
from pathlib import Path

from agents.evaluator.fixer.prompts import render_case_prompt, resolve_prompt_template
from agents.manager.case import CaseDefinition
from agents.manager.paths import instance_dir


REPO_ROOT = Path(__file__).resolve().parents[1]


class PromptRenderingTest(unittest.TestCase):
    def test_ca35_uses_the_fixer_prompt_template(self) -> None:
        case = CaseDefinition.load(instance_dir(REPO_ROOT, "CA35"))

        self.assertEqual(
            resolve_prompt_template(case),
            REPO_ROOT / "prompts/misconfig_troubleshooting.j2",
        )

    def test_ca35_task_prompt_is_rendered_from_template(self) -> None:
        case = CaseDefinition.load(instance_dir(REPO_ROOT, "CA35"))

        prompt = render_case_prompt(case)

        self.assertIn("# Misconfiguration Troubleshooting Task", prompt)
        self.assertIn("Instance ID:\nCA35", prompt)
        self.assertIn("Software:\nMySQL 8.0.27", prompt)
        self.assertIn("Reported Problem:", prompt)
        self.assertIn("# Troubleshooting Guidelines", prompt)
        self.assertIn("```bash\nmysql\n```", prompt)
        self.assertNotIn("option_value_escaping", prompt)


if __name__ == "__main__":
    unittest.main()
