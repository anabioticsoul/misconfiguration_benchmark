#!/usr/bin/env bash
set -euo pipefail

export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
start_log=/tmp/cb263-repro-start.log
if ! bash /opt/misconfigbench/start-hadoop.sh >"$start_log" 2>&1; then
  cat "$start_log"
  exit 1
fi

printf 'segment-121 payload for CB263\n' >/tmp/cb263-payload
"$HADOOP_HOME/bin/hdfs" dfs -mkdir -p /user/hadoop/cb263-input >/tmp/cb263-repro-mkdir.log 2>&1
rm -f /tmp/cb263-repro-put.log
set +e
"$HADOOP_HOME/bin/hdfs" dfs -put -f /tmp/cb263-payload /user/hadoop/cb263-input/segment-121 >/tmp/cb263-repro-put.log 2>&1
status=$?
set -e
cat /tmp/cb263-repro-put.log
if [[ "$status" -eq 0 ]]; then
  printf 'Expected HDFS put to fail, but it succeeded\n' >&2
  exit 1
fi
if ! grep -Eq 'could only be replicated to 0 nodes instead of minReplication \(=1\)|could only be written to 0 of the 1 minReplication nodes\.' /tmp/cb263-repro-put.log; then
  printf 'Expected block-placement diagnostic was not observed\n' >&2
  exit 1
fi
