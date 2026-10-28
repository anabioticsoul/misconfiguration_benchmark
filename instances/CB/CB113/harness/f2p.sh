#!/usr/bin/env bash
set -euo pipefail
source /etc/profile.d/java_home.sh
output=$(/usr/local/bin/java-home-check 2>&1)
grep -F 'version "11.' <<<"$output" >/dev/null
