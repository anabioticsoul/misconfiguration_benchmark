#!/usr/bin/env bash
set -euo pipefail
[ "$#" -ge 1 ] && [ "$#" -le 2 ]
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd158:latest}"
command -v docker >/dev/null
harness_dir="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
container="cd158-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for path in /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default~; do
  mkdir -p "$work$(dirname "$path")"
  if docker cp "$container:$path" "$work$path" 2>/dev/null; then :; fi
done
cd "$work"
git init -q
git config user.email evaluator@example.invalid
git config user.name evaluator
 git add -A
git commit -qm baseline
if ! git apply --unsafe-paths "$patch_file"; then exit 1; fi
changed="$(git diff --name-only HEAD)"
[ "$changed" = "etc/nginx/sites-enabled/default~" ] || exit 1
docker cp "$work/etc/nginx/sites-enabled/default~" "$container:/etc/nginx/sites-enabled/default~" 2>/dev/null || docker exec "$container" rm -f /etc/nginx/sites-enabled/default~
docker exec "$container" bash -lc 'if [ -e /etc/nginx/sites-enabled/default~ ]; then exit 1; fi'
docker exec "$container" bash -lc 'bash -s' < "$harness_dir/f2p.sh"
docker exec "$container" bash -lc 'bash -s' < "$harness_dir/p2p.sh"
