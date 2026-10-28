#!/usr/bin/env bash
set -euo pipefail
test -x /opt/hadoop/bin/hdfs
test -s /opt/hadoop/etc/hadoop/core-site.xml
grep -Fq '<name>fs.defaultFS</name>' /opt/hadoop/etc/hadoop/core-site.xml
