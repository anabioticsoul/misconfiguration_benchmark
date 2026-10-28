#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cc54:latest}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
name="cc54-eval-$$"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap cleanup EXIT
mkdir -p "$tmp/opt/cc54"
docker run -d --name "$name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$name:/opt/cc54/web.config" "$tmp/opt/cc54/web.config"
if docker exec -i "$name" bash -s < "$root/harness/f2p.sh" >/dev/null 2>&1; then
  echo 'faulty image unexpectedly passes'
  exit 1
fi
cd "$tmp"
git init -q
git config user.name evaluator
git config user.email evaluator@localhost
git add opt/cc54/web.config
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
[ "$(git diff --name-only)" = "opt/cc54/web.config" ]
cd "$root"
docker rm -f "$name" >/dev/null
name="cc54-eval-fixed-$$"
docker run -d --name "$name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$tmp/opt/cc54/web.config" "$name:/opt/cc54/web.config"
docker exec -i "$name" bash -s < "$root/harness/f2p.sh"
docker exec -i "$name" bash -s < "$root/harness/p2p.sh"
