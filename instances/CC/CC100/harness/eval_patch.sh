#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
script_dir="$(cd "$(dirname "$0")" && pwd)"
image="${2:-cc100:latest}"
root="$(mktemp -d)"
container="cc100-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/opt/cc100"
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/opt/cc100/pom.xml" "$root/opt/cc100/pom.xml"
git -C "$root" init -q
git -C "$root" add opt/cc100/pom.xml
git -C "$root" -c user.name=openhands -c user.email=openhands@all-hands.dev commit -q -m baseline
git -C "$root" apply --unsafe-paths "$patch_file"
changed=$(git -C "$root" diff --name-only)
[ "$changed" = "opt/cc100/pom.xml" ]
docker cp "$root/opt/cc100/pom.xml" "$container:/opt/cc100/pom.xml"
docker cp "$script_dir/f2p.sh" "$container:/harness-f2p.sh"
docker cp "$script_dir/p2p.sh" "$container:/harness-p2p.sh"
docker exec "$container" bash /harness-f2p.sh
docker exec "$container" bash /harness-p2p.sh
