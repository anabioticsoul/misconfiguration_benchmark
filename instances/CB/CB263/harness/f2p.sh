#!/usr/bin/env bash
set -euo pipefail

export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
start_log=/tmp/cb263-f2p-start.log
if ! bash /opt/misconfigbench/start-hadoop.sh >"$start_log" 2>&1; then
  cat "$start_log"
  exit 1
fi

printf 'segment-121 payload for CB263\n' >/tmp/cb263-payload
"$HADOOP_HOME/bin/hdfs" dfs -mkdir -p /user/hadoop/cb263-input >/tmp/cb263-f2p-mkdir.log 2>&1
rm -f /tmp/cb263-f2p-put.log
if ! "$HADOOP_HOME/bin/hdfs" dfs -put -f /tmp/cb263-payload /user/hadoop/cb263-input/segment-121 >/tmp/cb263-f2p-put.log 2>&1; then
  cat /tmp/cb263-f2p-put.log
  exit 1
fi
cat /tmp/cb263-f2p-put.log
if ! "$HADOOP_HOME/bin/hdfs" dfs -test -e /user/hadoop/cb263-input/segment-121; then
  printf 'HDFS put reported success but the destination is absent\n' >&2
  exit 1
fi
