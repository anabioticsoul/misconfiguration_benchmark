#!/usr/bin/env bash
set -euo pipefail
log=/tmp/cc81-repro.log
set +e
/opt/springboot/run.sh >"$log" 2>&1
status=$?
set -e
cat "$log"
test "$status" -ne 0
grep -F 'InaccessibleObjectException' "$log"
grep -F 'does not open java.lang' "$log"
