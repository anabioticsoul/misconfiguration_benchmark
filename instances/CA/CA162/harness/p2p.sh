#!/usr/bin/env bash
set -euo pipefail
[ -r /opt/misconfigbench/orc_config.conf ]
[ -x /opt/misconfigbench/run_orc_check.py ]
version_output="$(/opt/spark/bin/spark-submit --version 2>&1)"
grep -Fq "version 3.5.1" <<<"$version_output"
