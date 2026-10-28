#!/usr/bin/env bash
set -euo pipefail
log=/tmp/cc53-repro.log
set +e
output=$(apache2ctl -t 2>"$log")
status=$?
set -e
cat "$log"
if [ "$status" -eq 0 ]; then echo 'expected apache2ctl -t to fail' >&2; exit 1; fi
cat "$log" | grep -F "Invalid command 'Require'" >/dev/null || { echo 'expected missing Require diagnostic' >&2; exit 1; }
