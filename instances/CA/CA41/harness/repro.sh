#!/usr/bin/env bash
set -euo pipefail
log=/tmp/ca41-nginx-test.log
set +e
nginx -t >"$log" 2>&1
status=$?
set -e
cat "$log"
grep -F 'the "ssl" directive is deprecated' "$log"
grep -F 'use the "listen ... ssl" directive instead' "$log"
[ "$status" -eq 0 ]
