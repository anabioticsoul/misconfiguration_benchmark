# MisconfigBench Design

MisconfigBench evaluates troubleshooting rather than exact patch reproduction.
Each instance presents an operational symptom and accepts any repair that
restores the required behavior through the intended configuration surface.

## Agent Pipeline

MisconfigBench separates environment construction, validation, diagnosis, and
repair into four roles:

1. The builder agent creates an instance from its description, including the
   faulty Docker environment and case metadata.
2. The verifier agent checks that the instance reproduces the description and
   that its fail-to-pass, pass-to-pass, and evaluation paths behave correctly.
3. The diagnosis evaluator agent investigates a fresh faulty environment and
   returns a ranked, structured root-cause prediction. A private deterministic
   scorer evaluates that prediction without exposing oracle artifacts.
4. The fixer agent diagnoses and repairs the validated faulty environment.

Shared case loading, Docker lifecycle, run artifacts, evaluator invocation, and
OpenHands conversation management live in `agents/manager/`. Role packages may
depend on manager code, but manager code must not import builder, verifier, or
fixer packages.

## Public Task

The agent receives:

- the observable failure;
- the command used to reproduce it;
- the expected repaired behavior;
- broad safety constraints, such as preserving authentication.

In a live agent run, the agent should receive only the public task text and
access to the already-faulty container environment. It should not receive
`instance.json`, private metadata, reference patches, fail-to-pass tests,
pass-to-pass tests, or harness scripts.

The task must not state that the root cause is a configuration error, identify
the faulty option, or expose the reference patch.

For services with interactive clients, the public reproduction command can be
the natural user-facing command. Hidden fail-to-pass checks may use a
non-interactive equivalent so automated replay has deterministic exit behavior.

## Prompt Protocol

Each case stores its public task text in its own case directory, for example
`instances/CA/CA35/meta/description.md`. The fixer agent runner renders the
final agent task from a benchmark-level prompt template such as
`prompts/misconfig_troubleshooting.j2`.

`instance.json` declares the prompt protocol:

```json
{
  "prompt_protocol": {
    "template": "prompts/misconfig_troubleshooting.j2",
    "case_prompt": "meta/description.md"
  }
}
```

Prompt templates may include public case text and non-oracle metadata such as
instance id, task type, software name, and software version. They must not
include taxonomy ids, allowed files, required options, private metadata,
reference patches, fail-to-pass tests, pass-to-pass tests, or harness scripts.

## Private Oracle

Evaluator-only metadata records:

- the root-cause family and subtype;
- the intended configuration scope;
- allowed files and required options;
- forbidden shortcuts;
- fail-to-pass and pass-to-pass behavioral checks;
- a canonical patch for validation.

For diagnosis evaluation, `private_oracle.diagnosis_oracle.component` records
the canonical affected component. `faulty_targets` provides the canonical
configuration-level target `(path, section, option)`. The diagnostic agent sees
neither field.

Root-cause families and subtypes should follow `standards/taxonomy.json`.
Case metadata should reference the stable subtype id, such as `CA-1`, instead
of duplicating category names.

The canonical patch is an example repair, not the only accepted answer.

`required_modified_options` is optional. Use it when the instance is designed
to test repair of a specific option. Omit it when several configuration
changes are independently valid repairs.

## Evaluation

A prediction passes only when all of these conditions hold:

1. The patch modifies only the allowed configuration files.
2. The patch changes any required configuration option declared by the case.
3. The patch applies cleanly to a dynamic baseline extracted from a fresh
   faulty container/image.
4. The repaired environment satisfies the fail-to-pass oracle.
5. Pass-to-pass checks reject shortcut repairs that weaken the system.

For CA35, escaping the MySQL client password's literal backslash is the
canonical repair. The evaluator does not compare the final line against that
exact text; it checks that the client can connect and that an invalid password
is still rejected.

### Builder protocol

Instance construction is separate from fixer inference. For a new case, the
human-provided case-specific input is only `meta/description.md`. The builder
agent creates the remaining instance contract in an isolated run workspace.

Dockerfile templates are repository-level infrastructure shared by every case:

```text
templates/builder/
  Dockerfile.base.j2
  Dockerfile.instance.j2

instances/<ID>/
  meta/description.md
  instance.json
  meta/metadata.json
  meta/gold_patch.diff
  harness/
  build/
    build.json
    requirements.md
    context/
      base-overlay/
      fault-overlay/
      scripts/
```

The generic base template copies the clean overlay onto a clean source image.
The generic instance template derives from that base and copies only the fault
overlay. Optional per-layer scripts support deterministic service
initialization without making the Dockerfile case-specific.

Generation and acceptance are separate gates. OpenHands may propose files, but
the host manager performs Docker builds, symptom reproduction, gold-patch
application, and F2P/P2P validation. A fully generated case can later be rebuilt
with `--agent deterministic`.

## Distribution

Validated images have three resolution levels:

1. an existing local image for development;
2. an immutable registry `pull_reference` containing a sha256 digest;
3. an optional gzip-compressed `docker save` archive for offline use.

Registry publication is host-controlled. The builder agent cannot invent
`image.distribution`; it is recorded only after `docker push` succeeds and the
registry digest is available.

The public Hugging Face export contains task statements, software/source
metadata, and image distribution references. Private oracle metadata, reference
patches, and evaluator harnesses are excluded so publishing the Dataset does not
leak the repair.

## Score Dimensions

Keep the dimensions separate in result records even when the headline score is
binary:

- `configuration_intervention`: the repair uses the intended configuration
  surface;
- `symptom_resolution`: the original failure is gone;
- `shortcut_resistance`: negative checks still hold;
- `patch_hygiene`: unrelated files are untouched.

Trajectory analysis can separately measure whether the agent identified the
root cause efficiently. The task prompt should not reveal that root cause.

## Diagnosis Evaluation

Diagnosis is scored independently from repair and uses a structured ranked
prediction containing a taxonomy type/subtype and up to five candidate
locations. The primary metrics follow process-level diagnosis and fault
localization practice: Type and Subtype Macro-F1, subtype exact accuracy,
component and configuration-target Hit@1/3/5, MRR, MAP@5, and strict Joint@K
(correct subtype and a correct target in the top K). Invalid JSON predictions
remain in the denominator as all-zero predictions.

The evaluator does not use an LLM judge. Free-text rationales may be retained
for qualitative or human study, but the headline metrics are deterministic
comparisons against private taxonomy and target annotations.
