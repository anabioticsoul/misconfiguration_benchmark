#!/usr/bin/env bash
set -euo pipefail
source /etc/profile.d/java_home.sh
set +e
output=$(/usr/local/bin/java-home-check 2>&1)
status=$?
set -e
[[ "$status" -ne 0 ]]
grep -F 'JAVA_HOME does not contain a usable Java installation' <<<"$output" >/dev/null
printf '%s\n' "$output"
