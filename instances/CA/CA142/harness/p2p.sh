#!/usr/bin/env bash
set -euo pipefail

config=/etc/flink/flink-conf.yaml
test -x /opt/flink/bin/checkpoint-probe
test -f "$config"
grep -Fqx 'state.backend: filesystem' "$config"
grep -Fqx 'state.checkpoints.dir: s3p://gamma-flink-test-checkpoint/checkpoints/' "$config"
grep -Fqx 'state.savepoints.dir: s3p://gamma-flink-test-checkpoint/savepoints/' "$config"
