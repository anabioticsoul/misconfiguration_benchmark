#!/usr/bin/env bash
set -euo pipefail
export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
export PATH="$HADOOP_HOME/bin:$PATH"
test -x "$HADOOP_HOME/bin/hdfs"
"$HADOOP_HOME/bin/hdfs" version >/dev/null
"$HADOOP_HOME/bin/hdfs" getconf -confKey fs.defaultFS | grep -Fq 'hdfs://'
