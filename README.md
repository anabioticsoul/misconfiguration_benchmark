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
builder agent  -> creates the instance and faulty Docker environment
verifier agent -> validates description, reproduction, F2P, and P2P behavior
fixer agent    -> diagnoses and repairs a validated instance

agents/manager -> shared case, Docker, artifact, evaluator, and OpenHands logic
```

Agent roles depend on `agents/manager/`; the manager layer does not depend on
any role-specific package.

The controlled classification standard is stored in
`standards/taxonomy.json`. Architecture and protocol details are documented in
`docs/benchmark-design.md`.

## Build An Instance

For a new case, the only required case-specific input is:

```text
instances/<ID>/meta/description.md
```

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

## Fix An Instance

Use OpenHands subscription login:

```bash
python -m agents.fixer.run_case <ID> \
  --subscription-login \
  --model <subscription-supported-model>
```

When neither `LLM_API_KEY` nor `LLM_BASE_URL` is configured, subscription login
is selected automatically. To use an OpenAI API key instead:

```bash
export LLM_API_KEY=...
python -m agents.fixer.run_case <ID> --model <api-model>
```

For local debugging, operate the same container manually and exit the shell to
trigger the hidden replay evaluation:

```bash
python -m agents.fixer.run_case <ID> --agent manual
```

Each run writes:

```text
runs/<timestamp>-ca35/
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

The verifier checks the committed faulty image without rebuilding it. It starts
a fresh container, runs the reproduction script, then applies the reference
patch through the case evaluator:

```bash
python -m agents.verifier.run_case CA14
python -m agents.verifier.run_case CA35
```

## Test

```bash
python -m unittest discover -s tests -v
python -m agents.verifier.run_case CA35
```

The verifier loads the configured image archive when the expected image is not
already available locally.
