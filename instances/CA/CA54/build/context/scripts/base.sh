#!/usr/bin/env bash
set -euo pipefail
H=/opt/hadoop/etc/hadoop
mkdir -p "$H" /opt/hadoop/logs /tmp/hadoop-root
cat > "$H/core-site.xml" <<'XML'
<?xml version="1.0"?>
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:9000</value>
  </property>
</configuration>
XML
cat > "$H/hdfs-site.xml" <<'XML'
<?xml version="1.0"?>
<configuration>
  <property><name>dfs.replication</name><value>1</value></property>
  <property><name>dfs.namenode.name.dir</name><value>file:///tmp/hadoop-root/dfs/name</value></property>
  <property><name>dfs.datanode.data.dir</name><value>file:///tmp/hadoop-root/dfs/data</value></property>
</configuration>
XML
cat > "$H/mapred-site.xml" <<'XML'
<?xml version="1.0"?>
<configuration>
  <property><name>mapreduce.framework.name</name><value>yarn</value></property>
</configuration>
XML
cat > "$H/yarn-site.xml" <<'XML'
<?xml version="1.0"?>
<configuration>
  <property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
</configuration>
XML
chmod 0644 "$H"/*.xml
