#!/usr/bin/env bash
set -euo pipefail
export SPARK_LOCAL_IP=127.0.0.1
export SPARK_HOME=/opt/spark
export PYTHONPATH="$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip${PYTHONPATH:+:$PYTHONPATH}"
test -s /opt/ca163/socket_checkpoint.py
grep -F 'format("socket")' /opt/ca163/socket_checkpoint.py >/dev/null
python3 /opt/ca163/socket_checkpoint.py --smoke >/dev/null 2>&1
