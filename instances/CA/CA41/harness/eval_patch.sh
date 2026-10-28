#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca41:latest}"
root_dir="$(cd "$(dirname "$0")/.." && pwd)"
name="ca41-eval-$$"
work="$(mktemp -d)"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/etc/nginx/conf.d"
docker run --rm --entrypoint /bin/bash "$image" -lc 'cat /etc/nginx/conf.d/default.conf' > "$work/etc/nginx/conf.d/default.conf"
git -C "$work" init -q
git -C "$work" config user.email openhands@all-hands.dev
git -C "$work" config user.name openhands
git -C "$work" add .
git -C "$work" commit -qm baseline
git -C "$work" apply --unsafe-paths "$patch_file"
[ "$(git -C "$work" diff --name-only)" = "etc/nginx/conf.d/default.conf" ]
docker run -d --name "$name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do docker exec "$name" test -f /etc/nginx/conf.d/default.conf && break; sleep 1; done
docker cp "$work/etc/nginx/conf.d/default.conf" "$name:/etc/nginx/conf.d/default.conf"
docker exec -i "$name" bash -s < "$root_dir/harness/f2p.sh"
docker exec -i "$name" bash -s < "$root_dir/harness/p2p.sh"
