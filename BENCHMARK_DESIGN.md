# MisconfigBench Design

MisconfigBench evaluates troubleshooting rather than exact patch reproduction.
Each instance presents an operational symptom and accepts any repair that
restores the required behavior through the intended configuration surface.

## Public Task

The agent receives:

- the observable failure;
- the command used to reproduce it;
- the expected repaired behavior;
- broad safety constraints, such as preserving authentication.

The task must not state that the root cause is a configuration error, identify
the faulty option, or expose the reference patch.

## Private Oracle

Evaluator-only metadata records:

- the root-cause family and subtype;
- the intended configuration scope;
- allowed files and required options;
- forbidden shortcuts;
- positive and negative behavioral checks;
- a canonical patch for validation.

The canonical patch is an example repair, not the only accepted answer.

`required_modified_options` is optional. Use it when the instance is designed
to test repair of a specific option. Omit it when several configuration
changes are independently valid repairs.

## Evaluation

A prediction passes only when all of these conditions hold:

1. The patch modifies only the allowed configuration files.
2. The patch changes any required configuration option declared by the case.
3. The patch applies cleanly to an isolated baseline.
4. The repaired environment satisfies the positive behavioral oracle.
5. Negative checks reject shortcut repairs that weaken the system.

For CA35, quoting the MySQL client password is the canonical repair. The
evaluator does not compare the final line against that exact text; it checks
that the client can connect and that an invalid password is still rejected.

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
