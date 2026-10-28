#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca56:latest}"
root="$(mktemp -d)"
container="ca56-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/etc/nginx/conf.d"
git -C "$root" init -q
git -C "$root" config user.email evaluator@localhost
git -C "$root" config user.name evaluator
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/etc/nginx/conf.d/ca56.conf" "$root/etc/nginx/conf.d/ca56.conf"
git -C "$root" add etc/nginx/conf.d/ca56.conf
git -C "$root" commit -qm baseline
git -C "$root" apply --unsafe-paths "$patch_file"
changed=$(git -C "$root" diff --name-only)
[ "$changed" = "etc/nginx/conf.d/ca56.conf" ]
docker cp "$root/etc/nginx/conf.d/ca56.conf" "$container:/etc/nginx/conf.d/ca56.conf"
docker exec -i "$container" bash -s < "$(cd "$(dirname "$0")" && pwd)/f2p.sh"
docker exec -i "$container" bash -s < "$(cd "$(dirname "$0")" && pwd)/p2p.sh"
