#!/usr/bin/env bash
set -euo pipefail
cd /opt/cd107
output="$(java -cp "target/classes:$(cat classpath)" bench.App 2>&1)" || { printf '%s\n' "$output"; exit 1; }
grep -F "Hibernate SessionFactory initialized" <<<"$output"
