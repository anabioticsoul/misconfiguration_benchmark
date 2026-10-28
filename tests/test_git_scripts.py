from __future__ import annotations

import subprocess
import shutil
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class GitScriptsTest(unittest.TestCase):
    def audit_file(self, path: str, content: str, cleaned: bool = False) -> subprocess.CompletedProcess:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            shutil.copy(REPO_ROOT / "scripts/commit_local.sh", root / "scripts")
            shutil.copy(REPO_ROOT / ".gitignore", root)
            subprocess.run(["git", "init", "-q", directory], check=True)
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
            subprocess.run(["git", "-C", directory, "add", "-f", "--", path], check=True)
            if cleaned:
                target.write_text("clean worktree, secret still staged")
            return subprocess.run(
                ["bash", str(root / "scripts/commit_local.sh"), "--check-index"],
                capture_output=True, text=True,
            )

    def test_index_allows_instance_source_with_spaces(self) -> None:
        result = self.audit_file("instances/CA/CA1/meta/a description.md", "Test source")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_index_rejects_force_added_artifacts(self) -> None:
        for path in ("instances/CA/CA1/image/CA1.tar.gz", "logs/run.json", ".env", "assets/CA/CA1.md"):
            with self.subTest(path=path):
                self.assertNotEqual(self.audit_file(path, "artifact").returncode, 0)

    def test_index_checks_staged_content_not_worktree(self) -> None:
        result = self.audit_file("settings.txt", "hf_" + "x" * 30, cleaned=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("possible credential", result.stderr)

    def test_replacement_fixture_key_is_rejected(self) -> None:
        result = self.audit_file(
            "instances/CA/CA41/build/context/base-overlay/etc/nginx/ssl/server.key",
            "-----BEGIN " + "PRIVATE KEY-----\nnot the public fixture",
        )
        self.assertNotEqual(result.returncode, 0)

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
