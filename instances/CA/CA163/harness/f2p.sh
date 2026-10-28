#!/usr/bin/env bash
set -euo pipefail
export SPARK_LOCAL_IP=127.0.0.1
export SPARK_HOME=/opt/spark
export PYTHONPATH="$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip${PYTHONPATH:+:$PYTHONPATH}"
rm -rf /tmp/ca163-checkpoint
output="$(mktemp)"
trap 'rm -f "$output"' EXIT
python3 /opt/ca163/socket_checkpoint.py >"$output" 2>&1
if grep -F "This query does not support recovering from checkpoint location" "$output" >/dev/null; then
  cat "$output"
  exit 1
fi
