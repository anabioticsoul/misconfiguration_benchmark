#!/usr/bin/env bash
set -euo pipefail
log=/tmp/ca54-repro.log
set +e
/opt/hadoop/bin/hdfs getconf -confKey fs.defaultFS >"$log" 2>&1
status=$?
set -e
cat "$log"
[ "$status" -ne 0 ]
grep -Fq "Illegal to have multiple roots" "$log"
