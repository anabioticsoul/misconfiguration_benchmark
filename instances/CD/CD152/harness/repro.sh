#!/usr/bin/env bash
set -euo pipefail
export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
export PATH="$HADOOP_HOME/bin:$PATH"
log=$(mktemp)
trap 'rm -f "$log"' EXIT
set +e
"$HADOOP_HOME/bin/hdfs" dfs -ls / >"$log" 2>&1
status=$?
set -e
cat "$log"
test "$status" -ne 0
grep -Fq "Connection refused" "$log"
