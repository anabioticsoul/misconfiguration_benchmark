#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca102:latest}"
root="$(cd "$(dirname "$0")/.." && pwd)"
stage="$(mktemp -d)"
source_cid=""
patched_cid=""
cleanup() {
  if [ -n "$source_cid" ]; then docker rm "$source_cid" >/dev/null 2>&1 || true; fi
  if [ -n "$patched_cid" ]; then docker rm -f "$patched_cid" >/dev/null 2>&1 || true; fi
  rm -rf "$stage"
}
trap cleanup EXIT

mkdir -p "$stage/etc/nginx/conf.d"
source_cid="$(docker create "$image")"
docker cp "$source_cid:/etc/nginx/conf.d/default.conf" "$stage/etc/nginx/conf.d/default.conf"
cd "$stage"
git init -q
git config user.name "openhands"
git config user.email "openhands@all-hands.dev"
git add etc/nginx/conf.d/default.conf
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
if [ "$(git diff --name-only)" != "etc/nginx/conf.d/default.conf" ]; then
  echo "patch modified files outside the allowed configuration" >&2
  git diff --name-only >&2
  exit 1
fi

patched_cid="$(docker run -d --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null')"
docker cp "$stage/etc/nginx/conf.d/default.conf" "$patched_cid:/etc/nginx/conf.d/default.conf"
docker exec -i "$patched_cid" bash -s < "$root/harness/f2p.sh"
docker exec -i "$patched_cid" bash -s < "$root/harness/p2p.sh"
