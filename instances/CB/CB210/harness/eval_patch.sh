#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb210:latest}"
root="$(mktemp -d)"
cid="$(docker create "$image")"
cleanup() { docker rm -f "$cid" >/dev/null 2>&1 || true; docker rm -f "cb210-eval-$$" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/etc/php/8.1/cli/conf.d"
docker cp "$cid:/etc/php/8.1/cli/conf.d/99-cb210-memory.ini" "$root/etc/php/8.1/cli/conf.d/99-cb210-memory.ini"
cp "$patch_file" "$root/prediction.patch"
( cd "$root" && git apply --check --unsafe-paths prediction.patch && git apply --unsafe-paths prediction.patch )
[ "$(find "$root" -type f | wc -l | tr -d ' ')" -eq 2 ]
docker run -d --name "cb210-eval-$$" "$image" tail -f /dev/null >/dev/null
for i in $(seq 1 30); do docker inspect "cb210-eval-$$" >/dev/null 2>&1 && break; done
docker cp "$root/etc/php/8.1/cli/conf.d/99-cb210-memory.ini" "cb210-eval-$$:/etc/php/8.1/cli/conf.d/99-cb210-memory.ini"
harness_dir="$(cd "$(dirname "$0")" && pwd)"
docker exec "cb210-eval-$$" bash -lc 'bash -s' < "$harness_dir/f2p.sh"
docker exec "cb210-eval-$$" bash -lc 'bash -s' < "$harness_dir/p2p.sh"
