#!/usr/bin/env bash
set -euo pipefail

log=/tmp/cd170-repro.log
set +e
/opt/cd170/run.sh >"$log" 2>&1
status=$?
set -e
cat "$log"
if [ "$status" -eq 0 ]; then
    echo "expected Django startup to fail without psycopg2.extensions" >&2
    exit 1
fi
if ! grep -Fq "No module named 'psycopg2.extensions'" "$log"; then
    echo "expected psycopg2.extensions import error was not observed" >&2
    exit 1
fi
