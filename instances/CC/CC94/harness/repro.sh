#!/usr/bin/env bash
set -euo pipefail
cd /opt/cc94/app
set +e
output=$(./gradlew build -x check --offline 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -ne 0 ]
printf '%s\n' "$output" | grep -F 'component compatible with Java 17'
printf '%s\n' "$output" | grep -F 'consumer needed a runtime of a component compatible with Java 8'
