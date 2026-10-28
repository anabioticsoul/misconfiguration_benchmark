#!/usr/bin/env bash
set -euo pipefail
cd /opt/ted-search
output=$(java -cp /opt/ted-search App 2>&1)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -F "Started application with MemcachedCacheManager" >/dev/null
if grep -F "spring.cache.type=GENERIC" /opt/ted-search/application.properties >/dev/null; then
  echo "generic cache override remains" >&2
  exit 1
fi
