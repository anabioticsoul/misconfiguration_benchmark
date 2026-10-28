# MisconfigBench

The benchmark runner starts an already-faulty service container, gives an
OpenHands fixer agent the public task text plus tools that operate only inside
that container, exports the allowed configuration files, and evaluates the
resulting patch in a fresh container.

During a fixer run, container file editing is not blocked by the hidden allowed
file list. The runner exports only the private-policy repair surface and the
fresh evaluator rejects patches outside that surface.

Private metadata, reference patches, fail-to-pass tests, pass-to-pass tests,
and evaluator scripts remain on the host. They are not mounted into the agent
workspace or copied into the agent-visible container environment.

## Architecture

```text
builder agent  -> creates the faulty environment and automatically runs deterministic validation
verifier agent -> reviews description/environment/patch/tests consistency with an LLM
evaluator      -> independently dispatches troubleshooter or fixer
  troubleshooter -> diagnoses a validated instance and scores localization
  fixer          -> repairs a validated instance and evaluates the patch

agents/manager -> shared case, Docker, artifact, evaluator, and OpenHands logic
```

Agent roles depend on `agents/manager/`; the manager layer does not depend on
any role-specific package.

The controlled classification standard is stored in
`standards/taxonomy.json`. Architecture and protocol details are documented in
`docs/benchmark-design.md`. The ICLR paper-writing blueprint, including the
technical route and experimental agenda, is in
`docs/iclr-paper-writing.md`. The end-to-end workflow is visualized in
[`docs/workflow.md`](docs/workflow.md).

Instance counts and root-cause/subtype coverage are tracked in
[the coverage table](docs/instance-coverage.md). After adding or validating a
case, refresh the Markdown table and its auditable JSON records with:

```bash
python -m scripts.report_coverage
```

Counts use metadata taxonomy IDs and the latest saved builder validation (or legacy verifier results),
not case-name prefixes or fixer outcomes. This summarizes historical evidence;
it does not rerun Docker validation or certify unchanged image contents.

## Build An Instance

For a new case, the required case-specific input is the numbered source
description:

```text
assets/<TYPE>/<ID>.md
```

`<TYPE>` is the two-letter family in the instance ID, for example
`assets/CA/CA14.md` or `assets/CB/CB116.md`. Before Builder reads a case,
it checks for `instances/<ID>/meta/description.md`. If that file is missing,
Builder creates `instances/<ID>/` and initializes the description from the
asset; otherwise it leaves the existing instance description unchanged. The
generated instance keeps that copy as its public problem statement.

The OpenHands builder generates the manifest, private metadata, clean and
faulty overlays, reproduction tests, F2P/P2P tests, evaluator, and gold patch:

```bash
python -m agents.builder.run_case CA14 \
  --agent openhands \
  --subscription-login \
  --model <subscription-supported-model>
```

Generation occurs in `runs/<timestamp>-builder-<id>/instance_workspace`. The
host then builds the image, confirms that the faulty symptom reproduces, applies
the gold patch, and requires F2P/P2P to pass before publishing generated files
back to `instances/<ID>/`.

Once generated files are committed, rebuilding is deterministic and does not
call an LLM:

```bash
python -m agents.builder.run_case CA14 --agent deterministic
```

All cases use the repository-level templates in `templates/builder/`. A case
stores only `build/build.json`, private build requirements, optional layer
scripts, and its `base-overlay/` plus `fault-overlay/`. It must not contain
case-specific Dockerfile templates.

A reusable clean rootfs/base image is recommended for each software/version.
It avoids reinstalling and initializing the service for every case. The base
must have a reproducible registry tag or separately managed archive; a local
Docker tag alone is not portable.

## Publish Images

Publishing is optional. Create the ignored local configuration file once and
fill in its values:

```bash
cp .env.example .env
```

The publishing entry point loads `.env` automatically. It authenticates through
Docker's standard credential store when Docker Hub credentials are present:

```bash
python -m scripts.publish_images --dry-run
python -m scripts.publish_images
```

The default names are versioned:

```text
docker.io/<namespace>/misconfigbench-ca35:v0.2
```

Each successful push records `reference`, `digest`, and immutable
`pull_reference` under `image.distribution` in the case's `instance.json`.
The verifier and fixer prefer an existing local image, then pull by digest,
then fall back to the optional `image/<ID>.tar.gz` archive.

For a new case, Builder can publish immediately after validation:

```bash
python -m agents.builder.run_case CA35 \
  --agent deterministic \
  --push-image
```

Use `--registry ghcr.io` for GitHub Container Registry. Explicit process
environment variables take precedence over `.env`. Credentials are never
written to run results or passed as command-line arguments.

## Publish Dataset

Generate the public Hugging Face payload without credentials:

```bash
python -m scripts.publish_dataset
```

This writes `dist/huggingface/data.jsonl`, a dataset card, and the public
taxonomy. It intentionally excludes private metadata, reference patches, and
evaluator harnesses.

To create or update a Hugging Face Dataset repository:

```bash
python -m scripts.publish_dataset --upload
```

Use the variable names documented in `.env.example`, but put the real repository
and write token only in your local `.env`. Add `--private` when the Dataset
repository should be private. Publish Docker images first: Dataset upload rejects
cases that do not yet have an immutable image distribution.

## Publish To GitHub

GitHub contains source code, prompts, and instance definitions (build scripts,
test harnesses, and reference patches). Docker Hub stores the built images;
Hugging Face stores the public dataset and immutable image references. Instance
metadata remains in GitHub so builds and tests are reproducible.

The local `assets/`, `runs/`, `logs/`, `dist/`, generated coverage reports,
instance `image/` and `workspace/` directories, and image archives are ignored.
They remain on disk but are not committed. Supply raw `assets/` separately when
generating new cases; existing instance descriptions are retained in GitHub.
Real credentials belong only in the ignored `.env` file.

CA41 includes a public, self-signed localhost TLS test key. Never use it outside
the benchmark. The commit audit permits only that exact fixture's SHA-256;
replacement keys and other private keys are rejected.

Local commit and remote push are separate operations. First preview and create a
local commit:

```bash
./scripts/commit_local.sh --dry-run
./scripts/commit_local.sh
```

This command scans files for likely credentials, private keys, and GitHub's 100
MiB file limit, runs the tests, stages all non-ignored changes, and creates only
a local commit. Its default message is `feat: update benchmark`; use
`--message "..."` only when an override is needed.

Then preview and push the clean current branch to the existing `origin` GitHub
remote:

```bash
./scripts/publish_github.sh --dry-run
./scripts/publish_github.sh
```

The remote command never stages files or creates commits. It refuses a dirty
working tree and never force-pushes. Authentication comes from the local Git
credential helper or SSH configuration; credentials must not be placed in
either script.

Both commands audit the Git index before committing/pushing, including files
force-added despite ignore rules. `./scripts/commit_local.sh --check-index`
runs that audit alone. This does not remove files from earlier Git history.

## Requirements

- Python 3.12+
- Docker Desktop with the Docker daemon running
- `openhands-sdk`
- `huggingface-hub` for optional Dataset upload
- a clean source image named by the generated `build/build.json`

## Runtime Progress

Long-running agent and infrastructure stages emit a console heartbeat every 30
seconds. Docker builds also report their latest output line every 30 seconds and
write output continuously to the run's `docker_build.log`.

Set `MISCONFIGBENCH_HEARTBEAT_SECONDS` to change the interval. Each OpenHands
conversation has a 900-second wall-clock limit by default; configure it with
`MISCONFIGBENCH_AGENT_TIMEOUT_SECONDS` or `--agent-timeout`. Set either limit to
`0` to disable it.

Transient model-provider connection failures are retried by OpenHands. The
default policy makes 8 total attempts with exponential backoff from 2 to 30
seconds and a 600-second request timeout. Configure it in the ignored `.env`
file with `MISCONFIGBENCH_LLM_NUM_RETRIES`,
`MISCONFIGBENCH_LLM_RETRY_MULTIPLIER`,
`MISCONFIGBENCH_LLM_RETRY_MIN_WAIT_SECONDS`,
`MISCONFIGBENCH_LLM_RETRY_MAX_WAIT_SECONDS`, and
`MISCONFIGBENCH_LLM_REQUEST_TIMEOUT_SECONDS`. Retry attempts are reported in
the console.

On macOS, agents automatically inherit the HTTP(S) proxy configured in System
Settings when `HTTP_PROXY` and `HTTPS_PROXY` are not already set. On other
hosts, configure those standard environment variables in `.env` when the
network requires a proxy.

## Failure Logs

Builder, Fixer, and Verifier persist abnormal exits to
`logs/<timestamp>-<agent>-<case>-<pid>.json`. Each file contains one JSON
record with the agent role, case ID, exit code, run directory, and, when
available, the exception type, message, and traceback. Records point to the
corresponding `runs/<timestamp>-.../result.json` for the complete per-run
output. Logs are local-only and common API-key and Bearer-token forms are
redacted.

Every agent invocation also archives its console stream, including OpenHands
stage logs, to `logs/console/<case>/<timestamp>-<agent>-<pid>.log`. Console
archives are local-only.

## Agent Usage And Cost

Every OpenHands rollout writes `agent_usage.json` in its own run directory.
The Builder and Fixer copy an aggregate into `result.json` as `agent_usage`.
Builder aggregation includes its initial generation and every host-correction
rollout, so the reported per-case usage reflects the full construction attempt.

`agent_usage` records request count; prompt, completion, cache, and reasoning
tokens; and `estimated_cost_usd` when an API price is available. OpenAI
subscription runs record token usage but set the dollar estimate to `null`,
because a subscription does not expose a reliable per-token invoice. For an
OpenLux API model not known by the SDK, set these local `.env` values in USD per
one million tokens to enable an estimate:

```text
MISCONFIGBENCH_LLM_INPUT_COST_PER_1M_TOKENS=<input price>
MISCONFIGBENCH_LLM_OUTPUT_COST_PER_1M_TOKENS=<output price>
```

The `cost_status` field distinguishes `estimated`, `partial_estimate`,
`subscription_not_metered`, and `unavailable`.

## Root-Cause Diagnosis Evaluation

RQ2 oracle-guided repair and RQ3 evidence collection/replay are documented in
[the Chinese running guide](docs/rq2-rq3-usage.md). Reviewed annotations are
required for oracle repair and evidence replay; missing annotations are not
silently replaced with generated answers. Existing E2E behavior remains
available with `--repair-context none`.

### Batch Evaluation

Online evaluator presets in VS Code use `--all`, so no case ID is requested.
The shared `agents/manager/batch.py` discovers cases under
`instances/{CA,CB,CC,CD}/<ID>` in numeric order. Description-only or incomplete
cases are skipped with a reason. Each complete case is freshly checked by the
builder validation module (reproduction, pre-fix F2P/P2P, reference evaluation); only a
passing case reaches the selected LLM task. Historical success logs are not
treated as proof that the current environment still works. This adds Docker
validation time, but no LLM calls for cases that fail verification. The existing
runtime can load archived images or pull configured registry images; it does
not invoke the builder to generate missing instances.

```bash
python -m agents.evaluator.run_case --task troubleshooter --all \
  --llm-provider openlux --model <gateway-model>
python -m agents.evaluator.run_case --task fixer --all \
  --llm-provider openlux --model <gateway-model>
```

Runs are sequential; a case failure or nonzero exit is recorded and the next
case continues. Ctrl+C stops the batch, preserving progress. A batch returns
nonzero if any complete case fails verification/evaluation or none are found.
`completed` means the task runner returned zero, not necessarily a correct
diagnosis; diagnosis correctness remains in the per-case metrics.

```text
runs/<task>/<provider>/<model-directory>/<timestamp>-batch/
  batch_result.json          # progress, skipped reasons, per-case exit codes
  verification/<ID>/        # builder_validation result.json
  <ID>/                     # normal evaluator output and token/cost records
```

`--batch-dir` overrides the batch root and must name a new directory.
`--verify-timeout` controls each reproduction command timeout (default 120s).
Do not combine `--all` with a case ID, `--run-dir`, `--diagnosis-file`, or a
manual shell. Single-case CLI evaluation remains available as shown below.
The diagnosis report can summarize an entire batch directory.

Evaluation has two independent tasks under one entrypoint:

```text
agents/evaluator/
  run_case.py          # dispatch with --task troubleshooter|fixer
  troubleshooter/     # diagnosis agent, scoring, and diagnosis reports
  fixer/              # repair agent, patch export, and hidden replay evaluation
```

Troubleshooter never invokes fixer automatically. Fixer retains the existing
public-problem repair protocol; this refactor does not supply oracle root causes.
Shared runtime, logging, and token accounting remain in `agents/manager`.

The diagnosis evaluator assesses understanding and localization independently
from repair. It asks an OpenHands agent for a structured, ranked diagnosis in a
fresh case container, then scores that output using private metadata; the agent
never receives the metadata, gold patch, or harnesses.

```bash
python -m agents.evaluator.run_case --task troubleshooter CA1 \
  --llm-provider openai_subscription \
  --subscription-login \
  --model gpt-5.6-luna
```

It reports type/subtype exact matches, component and configuration-target
`Hit@1/3/5`, `MRR`, `MAP@5`, and strict `Joint@1/3/5` metrics. To score a saved
diagnosis without an LLM or Docker run:

```bash
python -m agents.evaluator.run_case --task troubleshooter CA1 --diagnosis-file prediction.json
```

Aggregate valid runs with:

```bash
python -m agents.evaluator.troubleshooter.report --runs-dir runs
```

The report contains a `groups` list, separated by provider, model, execution
mode, iteration budget, and timeout. Each group's `metrics` contains Type and
Subtype Macro-F1, exact accuracy, ranking metrics, joint diagnosis metrics,
and a per-subtype breakdown. `total_runs`, `scored_runs`, and `unscored_runs`
make failures before scoring visible; metrics cover scored runs only.

VS Code provides one OpenAI subscription entry and one generic OpenLux API
entry per LLM role. Use the same OpenLux entry for Claude, Gemini, DeepSeek,
or GPT, editing `--model` directly in `.vscode/launch.json`. All OpenLux models
share `OPENLUX_API_KEY` and `OPENLUX_API_URL` from the local `.env`.
For OpenAI-compatible gateway routing, use LiteLLM's `openai/` prefix before
the gateway model ID, for example `openai/claude-sonnet-4-20250514`,
`openai/gemini-2.5-pro`, or `openai/deepseek-chat`. These examples require the
corresponding aliases to be supported by your gateway. Pin versioned model IDs
for published experiments. Troubleshooter defaults to 30 iterations and fixer
to 40; both default to a 900-second conversation limit. Keep the case set,
prompt, iteration budget, and timeout fixed when comparing models within a task.
Live run results record the resolved model, provider, iteration budget, and
timeout in `experiment`, alongside the existing token/cost records. Offline
diagnosis scoring does not infer the model that produced the submitted file.

New evaluation outputs are grouped automatically:

```text
runs/
  troubleshooter/<provider>/<model-directory>/<timestamp>-<case>/
  fixer/<provider>/<model-directory>/<timestamp>-<case>/
```

Provider is the configured API provider (`openlux` or `openai_subscription`),
not an API key. Model names containing path separators or other unsafe
characters are sanitized and receive a hash suffix to distinguish similar
names; `experiment.model` always retains the exact model ID. Secrets and API
URLs are not included in these directory names or experiment metadata.
Explicit `--run-dir` still overrides the entire output path.

Offline diagnosis uses `troubleshooter/offline/unknown/`; manual repair uses
`fixer/manual/none/`. Neither is attributed to a live model. Existing runs
are not moved; reports place records without experiment metadata in an
`unknown` group. The report preset can scan the entire `runs` tree without
mixing models. Repeated cases count as separate runs, not deduplicated cases;
keep prompt/dataset variants in separate experiment roots when aggregating.

## Fix An Instance

Use OpenHands subscription login:

```bash
python -m agents.evaluator.run_case --task fixer <ID> \
  --subscription-login \
  --model <subscription-supported-model>
```

When neither `LLM_API_KEY` nor `LLM_BASE_URL` is configured, subscription login
is selected automatically. To use an OpenAI API key instead:

```bash
export LLM_API_KEY=...
python -m agents.evaluator.run_case --task fixer <ID> --model <api-model>
```

For local debugging, operate the same container manually and exit the shell to
trigger the hidden replay evaluation:

```bash
python -m agents.evaluator.run_case --task fixer <ID> --agent manual
```

Each run writes:

```text
runs/fixer/<provider>/<model-directory>/<timestamp>-ca35/
  agent_workspace/
  baseline/etc/mysql/my.cnf
  exported/etc/mysql/my.cnf
  openhands_state/
  prediction.diff
  result.json
  task_prompt.md
  trajectory.jsonl
```

`trajectory.jsonl` is present for OpenHands runs. `result.json` records the
replay evaluator output and final pass/fail status.

## Verify An Instance

Builder automatically validates before publishing. To recheck an existing image
without rebuilding or calling an LLM:

```bash
python -m agents.builder.run_case CA14 --validate-only
python -m agents.builder.run_case CA35 --validate-only
```

The verifier is now a read-only OpenHands consistency reviewer. It compares
the original asset description, generated artifacts, live image configuration,
and deterministic validation evidence. See [the review guide](docs/consistency-verifier.md).

```bash
python -m agents.verifier.run_case CA41 --llm-provider openlux --model YOUR_MODEL
```

## Test

```bash
python -m unittest discover -s tests -v
python -m agents.builder.run_case CA35 --validate-only
```

Review results are advisory model judgments, not substitutes for deterministic
tests or human dataset auditing.
