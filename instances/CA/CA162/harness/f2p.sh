#!/usr/bin/env bash
set -euo pipefail
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
set +e
/opt/spark/bin/spark-submit --master local[2] /opt/misconfigbench/run_orc_check.py >"$out" 2>&1
status=$?
set -e
cat "$out"
[ "$status" -eq 0 ] || exit 1
grep -Fq "ORC compression: SNAPPY" "$out"
grep -Fq "ORC rows: 32" "$out"
