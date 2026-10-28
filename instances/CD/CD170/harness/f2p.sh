#!/usr/bin/env bash
set -euo pipefail

log=/tmp/cd170-f2p.log
if /opt/cd170/run.sh >"$log" 2>&1; then
    cat "$log"
else
    status=$?
    cat "$log"
    echo "Django management check failed with exit code $status" >&2
    exit "$status"
fi
