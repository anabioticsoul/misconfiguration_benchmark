#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
script_dir="$(cd "$(dirname "$0")" && pwd)"
image="${2:-cb116:latest}"
root="$(mktemp -d)"
extract_container="cb116-extract-$$"
patched_container="cb116-patched-$$"
cleanup() { docker rm -f "$extract_container" "$patched_container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/etc/mysql/conf.d"
docker run -d --name "$extract_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$extract_container:/etc/mysql/conf.d/cb116.cnf" "$root/etc/mysql/conf.d/cb116.cnf"
docker rm -f "$extract_container" >/dev/null
cd "$root"
git init -q
git config user.email evaluator@example.invalid
git config user.name evaluator
git add .
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
test "$changed" = "etc/mysql/conf.d/cb116.cnf"
value="$(awk -F= '/^[[:space:]]*bind-address[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2}' etc/mysql/conf.d/cb116.cnf)"
test "$value" = localhost
docker run -d --name "$patched_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$root/etc/mysql/conf.d/cb116.cnf" "$patched_container:/etc/mysql/conf.d/cb116.cnf"
docker cp "$script_dir/f2p.sh" "$patched_container:/tmp/f2p.sh"
docker cp "$script_dir/p2p.sh" "$patched_container:/tmp/p2p.sh"
docker exec "$patched_container" bash /tmp/f2p.sh
docker exec "$patched_container" bash /tmp/p2p.sh
