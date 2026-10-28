#!/usr/bin/env bash
set -euo pipefail
output="$(mktemp)"
trap 'rm -f "$output"' EXIT
set +e
mono /opt/ca19/SurveyClient.exe >"$output" 2>&1
status=$?
set -e
cat "$output"
test "$status" -ne 0
grep -Fq "Unrecognized configuration section <userSettings>" "$output"
