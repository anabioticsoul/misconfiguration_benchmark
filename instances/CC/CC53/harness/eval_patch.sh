#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then echo "usage: $0 <prediction-patch> [image-name]" >&2; exit 2; fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cc53:latest}"
root="$(mktemp -d)"
container="cc53-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for i in $(seq 1 30); do docker exec "$container" test -f /etc/apache2/mods-enabled/authz_core.load && break; sleep 1; done
git init -q "$root"
mkdir -p "$root/etc/apache2/mods-enabled"
docker cp "$container:/etc/apache2/mods-enabled/authz_core.load" "$root/etc/apache2/mods-enabled/authz_core.load"
git -C "$root" add . && git -C "$root" -c user.name=baseline -c user.email=baseline@example.invalid commit -qm baseline
git -C "$root" apply --unsafe-paths "$patch_file"
allowed='etc/apache2/mods-enabled/authz_core.load'
changed=$(git -C "$root" diff --name-only)
[ "$changed" = "$allowed" ] || { echo "unexpected modified files: $changed" >&2; exit 1; }
docker cp "$root/etc/apache2/mods-enabled/authz_core.load" "$container:/etc/apache2/mods-enabled/authz_core.load"
script_dir="$(cd "$(dirname "$0")" && pwd)"
docker exec "$container" bash -lc 'bash -s' < "$script_dir/f2p.sh"
docker exec "$container" bash -lc 'bash -s' < "$script_dir/p2p.sh"
