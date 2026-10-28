#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb218:latest}"
root="$(mktemp -d)"
cleanup() { rm -rf "$root"; }
trap cleanup EXIT
container="cb218-eval-$$"
patched="cb218-patched-$$"
docker rm -f "$container" "$patched" >/dev/null 2>&1 || true
docker create --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$container" >/dev/null
mkdir -p "$root/opt/ted-search"
docker cp "$container:/opt/ted-search/application.properties" "$root/opt/ted-search/application.properties"
cp "$patch_file" "$root/prediction.diff"
cd "$root"
git init -q
git config user.email evaluator@example.invalid
git config user.name evaluator
git add opt/ted-search/application.properties
git commit -qm baseline
git apply --unsafe-paths "$root/prediction.diff"
changed=$(git diff --name-only)
test "$changed" = "opt/ted-search/application.properties"
docker rm -f "$container" >/dev/null
container=""
docker create --name "$patched" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$patched" >/dev/null
docker cp "$root/opt/ted-search/application.properties" "$patched:/opt/ted-search/application.properties"
docker exec "$patched" /bin/bash -lc 'cd /opt/ted-search && set +e; output=$(java -cp /opt/ted-search App 2>&1); status=$?; set -e; test "$status" -eq 0; printf "%s\\n" "$output" | grep -F "Started application with MemcachedCacheManager" >/dev/null'
docker exec "$patched" /bin/bash -lc 'grep -F "memcached.cache.servers: memcached:11211" /opt/ted-search/application.properties >/dev/null'
docker rm -f "$patched" >/dev/null
patched=""
