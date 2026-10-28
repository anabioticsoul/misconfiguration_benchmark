#!/usr/bin/env bash
set -euo pipefail
output=$(java -version 2>&1)
grep -F 'version "11.' <<<"$output" >/dev/null
