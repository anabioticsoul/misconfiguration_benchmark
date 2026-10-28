from __future__ import annotations

import asyncio
import ast
import json
import os
import tempfile
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from agents.manager.artifacts import create_run_dir
from agents.manager.observability import observe_stage
from agents.manager.openhands import (
    DEFAULT_SUBSCRIPTION_MODEL,
    OpenHandsConfig,
    _log_agent_progress,
    _run_conversation_with_timeout,
    summarize_agent_usage,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
ROLE_PACKAGES = {
    "agents.builder",
    "agents.evaluator",
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

    def test_openlux_model_uses_compatible_transport_without_changing_identity(self) -> None:
        for model in ("deepseek-v4.1-flash", "claude-test", "gemini-test", "vendor/model"):
            config = OpenHandsConfig(model=model, provider="openlux")
            self.assertEqual(config.sdk_model, f"openai/{model}")
            self.assertEqual(config.model, model)
        self.assertEqual(OpenHandsConfig(model="openai/test", provider="openlux").sdk_model,
                         "openai/test")
        self.assertEqual(OpenHandsConfig(model="gpt-5.4").sdk_model, "gpt-5.4")

    def test_llm_retry_configuration_reads_environment(self) -> None:
        with patch.dict(
            os.environ,
            {
                "MISCONFIGBENCH_LLM_NUM_RETRIES": "6",
                "MISCONFIGBENCH_LLM_RETRY_MULTIPLIER": "1.5",
                "MISCONFIGBENCH_LLM_RETRY_MIN_WAIT_SECONDS": "3",
                "MISCONFIGBENCH_LLM_RETRY_MAX_WAIT_SECONDS": "20",
                "MISCONFIGBENCH_LLM_REQUEST_TIMEOUT_SECONDS": "420",
            },
            clear=False,
        ):
            config = OpenHandsConfig.from_environment(model="test-model")

        self.assertEqual(config.llm_num_retries, 6)
        self.assertEqual(config.llm_retry_multiplier, 1.5)
        self.assertEqual(config.llm_retry_min_wait_seconds, 3)
        self.assertEqual(config.llm_retry_max_wait_seconds, 20)
        self.assertEqual(config.llm_request_timeout_seconds, 420)
        self.assertEqual(config.llm_kwargs()["num_retries"], 6)

    def test_api_token_prices_are_passed_to_the_llm(self) -> None:
        with patch.dict(
            os.environ,
            {
                "MISCONFIGBENCH_LLM_INPUT_COST_PER_1M_TOKENS": "2.5",
                "MISCONFIGBENCH_LLM_OUTPUT_COST_PER_1M_TOKENS": "10",
                "OPENLUX_API_KEY": "test-key",
                "OPENLUX_API_URL": "https://api.example.test/v1",
            },
            clear=False,
        ):
            config = OpenHandsConfig.from_environment(
                provider="openlux", model="test-model"
            )

        self.assertEqual(config.llm_kwargs()["input_cost_per_token"], 0.0000025)
        self.assertEqual(config.llm_kwargs()["output_cost_per_token"], 0.00001)

    def test_subscription_usage_is_not_converted_to_a_dollar_estimate(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            run_dir = Path(temporary_dir)
            (run_dir / "agent_usage.json").write_text(
                json.dumps(
                    {
                        "provider": "openai_subscription",
                        "model": "gpt-5.6",
                        "requests": 4,
                        "tokens": {
                            "prompt_tokens": 100,
                            "completion_tokens": 20,
                            "cache_read_tokens": 10,
                            "cache_write_tokens": 0,
                            "reasoning_tokens": 5,
                        },
                        "estimated_cost_usd": None,
                        "cost_status": "subscription_not_metered",
                    }
                ),
                encoding="utf-8",
            )

            summary = summarize_agent_usage(run_dir)

        self.assertEqual(summary["requests"], 4)
        self.assertEqual(summary["tokens"]["prompt_tokens"], 100)
        self.assertIsNone(summary["estimated_cost_usd"])
        self.assertEqual(summary["cost_status"], "subscription_not_metered")

    def test_usage_summary_aggregates_builder_correction_rollouts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            run_dir = Path(temporary_dir)
            correction_dir = run_dir / "correction-2"
            correction_dir.mkdir()
            for destination, requests, cost in (
                (run_dir / "agent_usage.json", 2, 0.15),
                (correction_dir / "agent_usage.json", 3, 0.25),
            ):
                destination.write_text(
                    json.dumps(
                        {
                            "provider": "openlux",
                            "model": "test-model",
                            "requests": requests,
                            "tokens": {
                                "prompt_tokens": 10,
                                "completion_tokens": 2,
                                "cache_read_tokens": 0,
                                "cache_write_tokens": 0,
                                "reasoning_tokens": 0,
                            },
                            "estimated_cost_usd": cost,
                            "cost_status": "configured_rates",
                        }
                    ),
                    encoding="utf-8",
                )

            summary = summarize_agent_usage(run_dir)

        self.assertEqual(summary["rollouts"], 2)
        self.assertEqual(summary["requests"], 5)
        self.assertEqual(summary["tokens"]["prompt_tokens"], 20)
        self.assertEqual(summary["estimated_cost_usd"], 0.4)
        self.assertEqual(summary["cost_status"], "estimated")

    def test_agent_progress_logs_actions_but_not_observations(self) -> None:
        action_event = SimpleNamespace(
            source="agent",
            tool_name="build_workspace",
            action=SimpleNamespace(operation="replace", path="harness/f2p.sh"),
            thought=[],
        )
        observation_event = SimpleNamespace(
            source="environment",
            tool_name="build_workspace",
            action=None,
            thought=[],
        )
        with patch("agents.manager.openhands.logger") as logger:
            _log_agent_progress(action_event)
            _log_agent_progress(observation_event)

        logger.info.assert_called_once_with(
            "OpenHands agent action: %s%s",
            "build_workspace",
            " (replace harness/f2p.sh)",
        )

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

    def test_openlux_credentials_are_read_only_for_openlux_provider(self) -> None:
        with patch.dict(
            os.environ,
            {
                "OPENLUX_API_KEY": "openlux-key",
                "OPENLUX_API_URL": "https://api.openlux.example/v1",
            },
            clear=False,
        ):
            config = OpenHandsConfig.from_environment(
                provider="openlux", model="openlux-model"
            )

        self.assertEqual(config.provider, "openlux")
        self.assertEqual(config.api_key, "openlux-key")
        self.assertEqual(config.base_url, "https://api.openlux.example/v1")
        self.assertFalse(config.should_use_subscription_login)

    def test_openlux_provider_requires_its_own_credentials(self) -> None:
        with patch.dict(
            os.environ,
            {"OPENLUX_API_KEY": "", "OPENLUX_API_URL": ""},
            clear=False,
        ):
            with self.assertRaisesRegex(ValueError, "OPENLUX_API_KEY"):
                OpenHandsConfig.from_environment(
                    provider="openlux", model="openlux-model"
                )

    def test_configured_run_directory_is_resolved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            configured = Path(temporary_dir) / "custom-run"

            run_dir = create_run_dir(REPO_ROOT, "CA35", str(configured))

        self.assertEqual(run_dir, configured.resolve())


if __name__ == "__main__":
    unittest.main()
