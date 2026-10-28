"""LLM-assisted consistency review; deterministic gates belong to the builder."""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from agents.manager import (CaseDefinition, ContainerRuntime, OpenHandsConfig, create_run_dir,
    configure_agent_failure_context, capture_agent_exception, load_repository_env,
    observe_stage, run_agent_entrypoint, run_openhands_agent, summarize_agent_usage)
from agents.manager.build import DockerInstanceBuilder, InstanceBuildDefinition
from agents.manager.paths import instance_dir
from agents.verifier.review import collect_evidence, parse_review

REPO_ROOT = Path(__file__).resolve().parents[2]


@observe_stage("verifier", "review_consistency", ignore_inputs=["prompt", "evidence", "run_dir", "config"])
def review_with_agent(prompt, evidence, run_dir, config):
    from agents.verifier.openhands_tools import register_review_tools
    return run_openhands_agent(prompt, register_review_tools(evidence), run_dir, config)


def main(argv=None):
    load_repository_env(REPO_ROOT)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("instance_id")
    parser.add_argument("--model")
    parser.add_argument("--llm-provider", choices=["openai_subscription", "openlux"],
                        default=os.getenv("MISCONFIGBENCH_LLM_PROVIDER", "openai_subscription"))
    parser.add_argument("--subscription-login", action="store_true")
    parser.add_argument("--max-iterations", type=int, default=30)
    parser.add_argument("--agent-timeout", type=int, default=900)
    parser.add_argument("--timeout", type=int, default=180, help="Deterministic test timeout")
    parser.add_argument("--run-dir")
    args = parser.parse_args(argv)
    run_dir = create_run_dir(REPO_ROOT, f"verifier-review-{args.instance_id}", args.run_dir)
    run_dir.mkdir(parents=True, exist_ok=False)
    configure_agent_failure_context(instance_id=args.instance_id, run_dir=run_dir)
    result = {"instance_id": args.instance_id, "agent_role": "verifier",
              "verification_kind": "consistency_review", "run_dir": str(run_dir),
              "started_at": datetime.now(timezone.utc).isoformat(), "success": False}
    try:
        config = OpenHandsConfig.from_environment(model=args.model, provider=args.llm_provider,
            subscription_login=args.subscription_login, max_iterations=args.max_iterations,
            max_runtime_seconds=args.agent_timeout)
        result["experiment"] = {"provider": config.provider, "model": config.model}
        case = CaseDefinition.load(instance_dir(REPO_ROOT, args.instance_id))
        ContainerRuntime(case)._ensure_image()
        validation = DockerInstanceBuilder(InstanceBuildDefinition.load(case), run_dir).validate(args.timeout)
        result["validation"] = validation
        evidence = collect_evidence(case, REPO_ROOT, validation)
        (run_dir / "evidence.json").write_text(json.dumps(evidence, indent=2, ensure_ascii=False))
        prompt = (REPO_ROOT / "prompts/instance_consistency.j2").read_text()
        prompt += "\n\nInstance: " + case.instance_id + "\nEvidence inventory:\n" + "\n".join(evidence)
        (run_dir / "task_prompt.md").write_text(prompt)
        response = review_with_agent(prompt, evidence, run_dir, config)
        result["agent_response"] = response
        review = parse_review(response, evidence)
        (run_dir / "review.json").write_text(json.dumps(review, indent=2, ensure_ascii=False))
        result["review"] = review
        result["success"] = validation["success"] and review["verdict"] == "consistent"
        return 0 if result["success"] else 1
    except Exception as exc:
        result["error"] = f"{type(exc).__name__}: {exc}"
        capture_agent_exception(exc)
        return 1
    finally:
        result["agent_usage"] = summarize_agent_usage(run_dir)
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
        (run_dir / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
        print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(run_agent_entrypoint("verifier", main))
