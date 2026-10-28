#!/usr/bin/env bash
set -euo pipefail

HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
export HADOOP_HOME
export HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-$HADOOP_HOME/etc/hadoop}"
export HDFS_NAMENODE_USER="$(id -un)"
export HDFS_DATANODE_USER="$(id -un)"

state_dir=/tmp/cb263-hadoop
log_dir="$state_dir/logs"
export HADOOP_LOG_DIR="$log_dir"
mkdir -p "$state_dir" "$log_dir" "$state_dir/nn"
for i in 1 2 3 4; do
  mkdir -p "$state_dir/dn$i"
done

report=""
if report=$("$HADOOP_HOME/bin/hdfs" dfsadmin -report 2>&1); then
  if [[ "$report" == *"Live datanodes (4)"* ]]; then
    printf '%s\n' "$report"
    exit 0
  fi
fi

if [[ ! -f "$state_dir/nn/current/VERSION" ]]; then
  rm -rf "$state_dir/nn/current"
  if ! "$HADOOP_HOME/bin/hdfs" namenode -format -force -nonInteractive >"$log_dir/namenode-format.log" 2>&1; then
    cat "$log_dir/namenode-format.log"
    exit 1
  fi
fi

if [[ ! -f "$state_dir/namenode.pid" ]] || ! kill -0 "$(cat "$state_dir/namenode.pid" 2>/dev/null || printf '0')" 2>/dev/null; then
  nohup "$HADOOP_HOME/bin/hdfs" namenode >"$log_dir/namenode.log" 2>&1 &
  printf '%s\n' "$!" >"$state_dir/namenode.pid"
fi

name_ready=0
for attempt in $(seq 1 60); do
  if "$HADOOP_HOME/bin/hdfs" dfsadmin -report >"$state_dir/name-report" 2>&1; then
    name_ready=1
    break
  fi
  sleep 1
done

if [[ "$name_ready" -ne 1 ]]; then
  cat "$log_dir/namenode.log" 2>/dev/null || true
  exit 1
fi

reserved=$(awk '
  /<name>dfs\.datanode\.du\.reserved<\/name>/ { want=1; next }
  want && /<value>/ {
    line=$0
    sub(/^.*<value>/, "", line)
    sub(/<\/value>.*$/, "", line)
    print line
    exit
  }
' "$HADOOP_CONF_DIR/hdfs-site.xml")
if [[ -z "$reserved" ]]; then
  printf 'Unable to read dfs.datanode.du.reserved\n' >&2
  exit 1
fi

for i in 1 2 3 4; do
  node_conf="$state_dir/conf-$i"
  rm -rf "$node_conf"
  mkdir -p "$node_conf"
  cp -a "$HADOOP_CONF_DIR/." "$node_conf/"
  cat >"$node_conf/hdfs-site.xml" <<EOF
<?xml version="1.0"?>
<configuration>
  <property><name>dfs.replication</name><value>1</value></property>
  <property><name>dfs.namenode.name.dir</name><value>file:///tmp/cb263-hadoop/nn</value></property>
  <property><name>dfs.namenode.rpc-address</name><value>localhost:9000</value></property>
  <property><name>dfs.datanode.data.dir</name><value>file:///tmp/cb263-hadoop/dn$i</value></property>
  <property><name>dfs.datanode.address</name><value>localhost:$((10000 + i))</value></property>
  <property><name>dfs.datanode.http.address</name><value>localhost:$((11000 + i))</value></property>
  <property><name>dfs.datanode.ipc.address</name><value>localhost:$((12000 + i))</value></property>
  <property><name>dfs.datanode.du.reserved</name><value>$reserved</value></property>
</configuration>
EOF
  pid_file="$state_dir/datanode-$i.pid"
  if [[ ! -f "$pid_file" ]] || ! kill -0 "$(cat "$pid_file" 2>/dev/null || printf '0')" 2>/dev/null; then
    mkdir -p "$state_dir/pids-$i"
    nohup env HADOOP_PID_DIR="$state_dir/pids-$i" HADOOP_CONF_DIR="$node_conf" HADOOP_LOG_DIR="$log_dir" "$HADOOP_HOME/bin/hdfs" datanode >"$log_dir/datanode-$i.log" 2>&1 &
    printf '%s\n' "$!" >"$pid_file"
  fi
done

for attempt in $(seq 1 60); do
  report=$("$HADOOP_HOME/bin/hdfs" dfsadmin -report 2>&1 || true)
  if [[ "$report" == *"Live datanodes (4)"* ]]; then
    printf '%s\n' "$report"
    exit 0
  fi
  sleep 1
done
printf '%s\n' "$report"
for log in "$log_dir"/*.log; do
  printf '\n===== %s =====\n' "$log"
  cat "$log" 2>/dev/null || true
done
exit 1
