#!/usr/bin/env bash
set -euo pipefail

patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cc72:latest}"
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
container="cc72-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT

mkdir -p "$work/opt/rector-demo"
docker run -d --name "$container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/opt/rector-demo/composer.json" "$work/opt/rector-demo/composer.json"
docker rm -f "$container" >/dev/null
cd "$work"
git init -q
git config user.email evaluator@localhost
git config user.name evaluator
git add opt/rector-demo/composer.json
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
[ "$changed" = "opt/rector-demo/composer.json" ] || { echo "Patch changed forbidden files: $changed" >&2; exit 1; }

docker run -d --name "$container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$work/opt/rector-demo/composer.json" "$container:/opt/rector-demo/composer.json"
for _ in $(seq 1 60); do
  if docker exec "$container" test -x /opt/rector-demo/vendor/bin/rector; then break; fi
  sleep 1
done
docker exec "$container" test -x /opt/rector-demo/vendor/bin/rector
docker exec "$container" bash -lc 'cd /opt/rector-demo && bash -s' < "$root/harness/f2p.sh"
docker exec "$container" bash -lc 'cd /opt/rector-demo && bash -s' < "$root/harness/p2p.sh"
