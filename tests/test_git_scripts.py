from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class GitScriptsTest(unittest.TestCase):
    def test_shell_scripts_have_valid_bash_syntax(self) -> None:
        for relative in (
            "scripts/commit_local.sh",
            "scripts/publish_github.sh",
        ):
            completed = subprocess.run(
                ["bash", "-n", str(REPO_ROOT / relative)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_local_script_does_not_push(self) -> None:
        source = (REPO_ROOT / "scripts/commit_local.sh").read_text()
        self.assertNotIn("git_repo push", source)

    def test_remote_script_does_not_stage_or_commit(self) -> None:
        source = (REPO_ROOT / "scripts/publish_github.sh").read_text()
        self.assertNotIn("git_repo add", source)
        self.assertNotIn("git_repo commit", source)

    def test_scripts_do_not_require_interactive_input(self) -> None:
        for relative in (
            "scripts/commit_local.sh",
            "scripts/publish_github.sh",
        ):
            source = (REPO_ROOT / relative).read_text()
            self.assertNotIn("read -r answer", source)

    def test_local_script_has_default_message(self) -> None:
        source = (REPO_ROOT / "scripts/commit_local.sh").read_text()
        self.assertIn('message="feat: update benchmark"', source)
        self.assertIn('cd "$REPO_ROOT"', source)


if __name__ == "__main__":
    unittest.main()
