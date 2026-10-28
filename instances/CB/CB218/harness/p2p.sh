#!/usr/bin/env bash
set -euo pipefail
config=/opt/ted-search/application.properties
grep -F "memcached.cache.servers: memcached:11211" "$config" >/dev/null
grep -F "memcached.cache.mode: static" "$config" >/dev/null
grep -F "memcached.cache.protocol: text" "$config" >/dev/null
