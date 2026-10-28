#!/usr/bin/env bash
set -euo pipefail
log=/tmp/cc81-f2p.log
set +e
/opt/springboot/run.sh >"$log" 2>&1
status=$?
set -e
cat "$log"
test "$status" -eq 0
grep -F 'Started Application with Spring Boot 2.0.5.RELEASE' "$log"
