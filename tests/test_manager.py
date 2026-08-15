from __future__ import annotations

import asyncio
import ast
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from agents.manager.artifacts import create_run_dir
from agents.manager.observability import observe_stage
from agents.manager.openhands import (
    DEFAULT_SUBSCRIPTION_MODEL,
    OpenHandsConfig,
    _run_conversation_with_timeout,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
ROLE_PACKAGES = {
    "agents.builder",
    "agents.fixer",
    "agents.verifier",
}


class ManagerArchitectureTest(unittest.TestCase):
    def test_openhands_conversation_has_wall_clock_timeout(self) -> None:
        class HangingConversation:
            def __init__(self) -> None:
                self.interrupted = False
                self.stopped = asyncio.Event()

            async def arun(self) -> None:
                await self.stopped.wait()

            def interrupt(self) -> None:
                self.interrupted = True
                self.stopped.set()

        conversation = HangingConversation()
        with self.assertRaisesRegex(TimeoutError, "exceeded"):
            asyncio.run(_run_conversation_with_timeout(conversation, 0.01))

        self.assertTrue(conversation.interrupted)

    def test_observed_stage_emits_periodic_heartbeat(self) -> None:
        @observe_stage("test", "slow_operation", heartbeat_seconds=0.01)
        def slow_operation() -> str:
            time.sleep(0.035)
            return "done"

        with patch("agents.manager.observability.logger") as logger:
            self.assertEqual(slow_operation(), "done")

        heartbeat_messages = [
            call
            for call in logger.info.call_args_list
            if call.args and str(call.args[0]).startswith("Still running")
        ]
        self.assertGreaterEqual(len(heartbeat_messages), 2)

    def test_manager_does_not_import_role_packages(self) -> None:
        violations: list[str] = []
        for source_path in (REPO_ROOT / "agents" / "manager").glob("*.py"):
            tree = ast.parse(source_path.read_text(encoding="utf-8"))
            for node in ast.walk(tree):
                imported_modules: list[str] = []
                if isinstance(node, ast.Import):
                    imported_modules = [alias.name for alias in node.names]
                elif isinstance(node, ast.ImportFrom) and node.module:
                    imported_modules = [node.module]

                for module in imported_modules:
                    if any(
                        module == role or module.startswith(f"{role}.")
                        for role in ROLE_PACKAGES
                    ):
                        violations.append(f"{source_path.name}: {module}")

        self.assertEqual(violations, [])

    def test_manager_does_not_select_a_role_prompt(self) -> None:
        manager_source = "\n".join(
            source_path.read_text(encoding="utf-8")
            for source_path in (REPO_ROOT / "agents" / "manager").glob("*.py")
        )

        self.assertNotIn("misconfig_troubleshooting.j2", manager_source)

    def test_shared_run_configuration_is_role_neutral(self) -> None:
        config = OpenHandsConfig(model="test-model", max_iterations=12)

        self.assertEqual(config.model, "test-model")
        self.assertEqual(config.max_iterations, 12)
        self.assertEqual(config.max_runtime_seconds, 900)
        self.assertFalse(config.subscription_login)
        self.assertTrue(config.should_use_subscription_login)
        self.assertEqual(DEFAULT_SUBSCRIPTION_MODEL, "gpt-5.4")

    def test_api_credentials_override_automatic_subscription_login(self) -> None:
        api_config = OpenHandsConfig(model="test-model", api_key="test-key")
        local_config = OpenHandsConfig(model="test-model", base_url="http://localhost")
        forced_config = OpenHandsConfig(
            model="test-model",
            api_key="test-key",
            subscription_login=True,
        )

        self.assertFalse(api_config.should_use_subscription_login)
        self.assertFalse(local_config.should_use_subscription_login)
        self.assertTrue(forced_config.should_use_subscription_login)

    def test_configured_run_directory_is_resolved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            configured = Path(temporary_dir) / "custom-run"

            run_dir = create_run_dir(REPO_ROOT, "CA35", str(configured))

        self.assertEqual(run_dir, configured.resolve())


if __name__ == "__main__":
    unittest.main()
