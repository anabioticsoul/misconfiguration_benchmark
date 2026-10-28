#!/usr/bin/env bash
set -euo pipefail
cd /opt/cd107
output="$(java -cp "target/classes:$(cat classpath)" bench.App 2>&1)" && status=0 || status=$?
printf '%s\n' "$output" >&2
test "$status" -ne 0
grep -F "Access to DialectResolutionInfo cannot be null when 'hibernate.dialect' not set" <<<"$output"
