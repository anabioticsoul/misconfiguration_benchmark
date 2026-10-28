#!/usr/bin/env bash
set -euo pipefail
log=/tmp/ca54-f2p.log
set +e
/opt/hadoop/bin/hdfs getconf -confKey fs.defaultFS >"$log" 2>&1
status=$?
set -e
cat "$log"
[ "$status" -eq 0 ]
grep -Fq 'hdfs://localhost:9000' "$log"
