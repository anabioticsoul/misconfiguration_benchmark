#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd79:latest}"
root_dir="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
container="cd79-eval-base-$$"
patched_container="cd79-eval-patched-$$"
cleanup() { docker rm -f "$container" "$patched_container" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/etc/apache2/sites-available"
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/etc/apache2/sites-available/000-default.conf" "$work/etc/apache2/sites-available/000-default.conf"
printf 'baseline\n' > "$work/.gitignore"
git -C "$work" init -q
git -C "$work" add .
git -C "$work" -c user.name=baseline -c user.email=baseline@example.invalid commit -q -m baseline
git -C "$work" apply --unsafe-paths "$patch_file"
changed=$(git -C "$work" diff --name-only)
[ "$changed" = "etc/apache2/sites-available/000-default.conf" ]
cp "$work/etc/apache2/sites-available/000-default.conf" "$work/patched.conf"
docker rm -f "$container" >/dev/null
docker run -d --name "$patched_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$work/patched.conf" "$patched_container:/etc/apache2/sites-available/000-default.conf"
docker exec "$patched_container" bash -lc 'apache2ctl -t'
docker exec "$patched_container" bash -lc 'bash -s' < "$root_dir/harness/f2p.sh"
docker exec "$patched_container" bash -lc 'bash -s' < "$root_dir/harness/p2p.sh"
