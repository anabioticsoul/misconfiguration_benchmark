#!/usr/bin/env bash
set -euo pipefail

export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
start_log=/tmp/cb263-p2p-start.log
if ! bash /opt/misconfigbench/start-hadoop.sh >"$start_log" 2>&1; then
  cat "$start_log"
  exit 1
fi

report=$("$HADOOP_HOME/bin/hdfs" dfsadmin -report 2>&1)
if [[ "$report" != *"Live datanodes (4)"* ]]; then
  printf '%s\n' "$report" >&2
  printf 'Expected four live DataNodes\n' >&2
  exit 1
fi
"$HADOOP_HOME/bin/hdfs" dfs -ls / >/tmp/cb263-p2p-ls.log 2>&1
cat /tmp/cb263-p2p-ls.log
if ! grep -Fq '<name>dfs.datanode.du.reserved</name>' "$HADOOP_CONF_DIR/hdfs-site.xml"; then
  printf 'The DataNode capacity setting disappeared\n' >&2
  exit 1
fi
