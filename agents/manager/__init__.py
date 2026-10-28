"""Shared orchestration primitives for benchmark agents."""

from pathlib import Path

from agents.manager.artifacts import build_prediction_patch, create_run_dir
from agents.manager.build import DockerInstanceBuilder, InstanceBuildDefinition
from agents.manager.case import CaseDefinition
from agents.manager.container_runtime import (
    CommandResult,
    ContainerRuntime,
    RuntimeErrorWithOutput,
)
from agents.manager.distribution import (
    RegistryConfig,
    login_registry,
    push_registry_image,
    record_image_distribution,
)
from agents.manager.evaluation import evaluate_prediction
from agents.manager.failure_log import (
    capture_agent_exception,
    configure_agent_failure_context,
    run_agent_entrypoint,
)
from agents.manager.openhands import (
    DEFAULT_LLM_PROVIDER,
    DEFAULT_SUBSCRIPTION_MODEL,
    OpenHandsConfig,
    run_openhands_agent,
    summarize_agent_usage,
)
from agents.manager.observability import observe_stage
from agents.manager.settings import load_repository_env
from agents.manager.templates import render_template
from agents.manager.workspace import WorkspaceFiles
from agents.manager.validation import ContractValidationError, load_case_documents

REPO_ROOT = Path(__file__).resolve().parents[2]
TAXONOMY_PATH = REPO_ROOT / "standards" / "taxonomy.json"

__all__ = [
    "CaseDefinition",
    "CommandResult",
    "ContainerRuntime",
    "ContractValidationError",
    "DEFAULT_SUBSCRIPTION_MODEL",
    "DEFAULT_LLM_PROVIDER",
    "DockerInstanceBuilder",
    "InstanceBuildDefinition",
    "OpenHandsConfig",
    "RuntimeErrorWithOutput",
    "RegistryConfig",
    "TAXONOMY_PATH",
    "build_prediction_patch",
    "capture_agent_exception",
    "configure_agent_failure_context",
    "create_run_dir",
    "evaluate_prediction",
    "load_case_documents",
    "load_repository_env",
    "login_registry",
    "observe_stage",
    "push_registry_image",
    "record_image_distribution",
    "render_template",
    "run_agent_entrypoint",
    "run_openhands_agent",
    "summarize_agent_usage",
    "WorkspaceFiles",
]
