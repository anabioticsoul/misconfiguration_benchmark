#!/usr/bin/env bash
set -euo pipefail
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
set +e
/opt/spark/bin/spark-submit --master local[2] /opt/misconfigbench/run_orc_check.py >"$out" 2>&1
status=$?
set -e
cat "$out"
if [ "$status" -eq 0 ]; then
  echo "expected Spark ORC verification to fail" >&2
  exit 1
fi
if ! grep -Fq "Expected SNAPPY compression but found" "$out"; then
  echo "expected compression mismatch was not reported" >&2
  exit 1
fi
