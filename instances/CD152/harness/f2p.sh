#!/usr/bin/env bash
set -euo pipefail
export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
export PATH="$HADOOP_HOME/bin:$PATH"
if grep -Fq 'hdfs://127.0.0.2:8020' "$HADOOP_HOME/etc/hadoop/core-site.xml"; then
  set +e
  "$HADOOP_HOME/bin/hdfs" dfs -ls / >/tmp/cd152-f2p.log 2>&1
  status=$?
  set -e
  cat /tmp/cd152-f2p.log
  test "$status" -ne 0
  grep -Fq "Connection refused" /tmp/cd152-f2p.log
  exit 1
fi
"$HADOOP_HOME/bin/hdfs" namenode -format -force -nonInteractive >/tmp/cd152-format.log 2>&1
"$HADOOP_HOME/bin/hdfs" --daemon start namenode
for _ in $(seq 1 30); do
  if "$HADOOP_HOME/bin/hdfs" dfs -ls / >/tmp/cd152-f2p.log 2>&1; then
    cat /tmp/cd152-f2p.log
    exit 0
  fi
  sleep 1
done
cat /tmp/cd152-f2p.log
exit 1
