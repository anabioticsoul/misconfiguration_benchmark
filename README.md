# MisconfigBench MVP

The MVP runner starts a faulty service container, gives an OpenHands agent tools
that operate only inside that container, exports the allowed configuration
files, and evaluates the resulting patch in a fresh container.

Private metadata, reference patches, and evaluator scripts remain on the host.
They are not mounted into the agent workspace.

## Requirements

- Python 3.12+
- Docker Desktop with the Docker daemon running
- `openhands-sdk`
- the CA35 root filesystem archive at `instances/CA35/image/CA35.tar.gz`

## Run CA35

Use an OpenAI API key:

```bash
export LLM_API_KEY=...
python -m benchmark.run_case CA35 --model openai/gpt-5.2-codex
```

Use OpenHands subscription login:

```bash
python -m benchmark.run_case CA35 \
  --subscription-login \
  --model gpt-5.2-codex
```

For local debugging, operate the same container manually and exit the shell to
trigger the hidden replay evaluation:

```bash
python -m benchmark.run_case CA35 --agent manual
```

Each run writes:

```text
runs/<timestamp>-ca35/
  agent_workspace/
  exported/etc/mysql/my.cnf
  prediction.diff
  result.json
  trajectory.jsonl
```

`trajectory.jsonl` is present for OpenHands runs. `result.json` records the
replay evaluator output and final pass/fail status.

## Test

```bash
python -m unittest discover -s tests -v
bash instances/CA35/harness/validate.sh
```

The shell validator imports the archived root filesystem if `ca35:latest` is
not already available.
