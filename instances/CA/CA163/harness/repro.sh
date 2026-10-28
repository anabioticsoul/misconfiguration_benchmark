#!/usr/bin/env bash
set -euo pipefail
export SPARK_LOCAL_IP=127.0.0.1
export SPARK_HOME=/opt/spark
export PYTHONPATH="$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip${PYTHONPATH:+:$PYTHONPATH}"
output="$(mktemp)"
trap 'rm -f "$output"' EXIT
set +e
python3 /opt/ca163/socket_checkpoint.py >"$output" 2>&1
status=$?
set -e
cat "$output"
[ "$status" -ne 0 ]
grep -F "This query does not support recovering from checkpoint location" "$output" >/dev/null
