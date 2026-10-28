#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca162:latest}"
root="$(mktemp -d)"
container="ca162-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/work"
git -C "$root/work" init -q
git -C "$root/work" config user.email openhands@all-hands.dev
git -C "$root/work" config user.name openhands
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do
  if docker exec "$container" test -f /opt/misconfigbench/orc_config.conf; then break; fi
  sleep 1
done
docker cp "$container:/opt/misconfigbench/orc_config.conf" "$root/work/orc_config.conf"
git -C "$root/work" add orc_config.conf
git -C "$root/work" commit -q -m baseline
git -C "$root/work" apply --unsafe-paths "$patch_file"
if [ "$(git -C "$root/work" diff --name-only)" != "orc_config.conf" ]; then
  echo "patch modified files outside the allowed configuration" >&2
  exit 1
fi
docker cp "$root/work/orc_config.conf" "$container:/opt/misconfigbench/orc_config.conf"
docker exec -i "$container" bash -s < "$(cd "$(dirname "$0")" && pwd)/f2p.sh"
docker exec -i "$container" bash -s < "$(cd "$(dirname "$0")" && pwd)/p2p.sh"
