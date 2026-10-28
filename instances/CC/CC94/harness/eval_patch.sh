#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cc94:latest}"
root="$(cd "$(dirname "$0")/.." && pwd)"
name="cc94-eval-$$"
fixed_name="${name}-fixed"
cleanup() {
  docker rm -f "$name" "$fixed_name" >/dev/null 2>&1 || true
  rm -rf "$extract"
}
trap cleanup EXIT
extract="$root/.eval-cc94-$$"
mkdir -p "$extract/opt/cc94/app"
docker create --name "$name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$name" >/dev/null
docker cp "$name:/opt/cc94/app/system.properties" "$extract/opt/cc94/app/system.properties"
cd "$extract"
git init -q
git config user.email openhands@all-hands.dev
git config user.name openhands
git add opt/cc94/app/system.properties
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
[ "$changed" = "opt/cc94/app/system.properties" ]
docker rm -f "$name" >/dev/null
docker create --name "$fixed_name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$fixed_name" >/dev/null
docker cp opt/cc94/app/system.properties "$fixed_name:/opt/cc94/app/system.properties"
set +e
docker exec -i "$fixed_name" bash -s < "$root/harness/f2p.sh"
f2p=$?
docker exec -i "$fixed_name" bash -s < "$root/harness/p2p.sh"
p2p=$?
set -e
[ "$f2p" -eq 0 ] && [ "$p2p" -eq 0 ]
