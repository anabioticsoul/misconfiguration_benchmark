#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd92:latest}"
self_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
name="cd92-eval-$$"
work="$(mktemp -d)"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/opt/cd92"
docker run --name "$name" -d --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do docker exec "$name" test -f /opt/cd92/logback.xml && break; sleep 1; done
docker cp "$name:/opt/cd92/logback.xml" "$work/opt/cd92/logback.xml"
cd "$work"
git init -q
git config user.name evaluator
git config user.email evaluator@example.invalid
git add . && git commit -qm baseline
git apply --unsafe-paths "$patch_file"
[ "$(git diff --name-only)" = "opt/cd92/logback.xml" ]
cd - >/dev/null
# Evaluate repaired behavior in a fresh container, avoiding state from patch staging.
docker rm -f "$name" >/dev/null
name="cd92-eval-repaired-$$"
docker run --name "$name" -d --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do docker exec "$name" test -f /opt/cd92/logback.xml && break; sleep 1; done
docker cp "$work/opt/cd92/logback.xml" "$name:/opt/cd92/logback.xml"
docker exec -i "$name" bash -s < "$self_dir/f2p.sh"
docker exec -i "$name" bash -s < "$self_dir/p2p.sh"
