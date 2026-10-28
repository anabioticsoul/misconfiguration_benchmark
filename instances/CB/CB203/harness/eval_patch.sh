#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb203:latest}"
work="$(mktemp -d)"
source_container="cb203-source-$$"
fixed_container="cb203-fixed-$$"
cleanup() {
  docker rm -f "$source_container" "$fixed_container" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/etc/nginx/conf.d"
docker create --name "$source_container" "$image" >/dev/null
docker cp "$source_container:/etc/nginx/conf.d/default.conf" "$work/etc/nginx/conf.d/default.conf"
printf 'baseline\n' > "$work/.baseline"
git -C "$work" init -q
git -C "$work" config user.name openhands
git -C "$work" config user.email openhands@all-hands.dev
git -C "$work" add .
git -C "$work" commit -qm baseline
GIT_CONFIG_NOSYSTEM=1 git -C "$work" apply --unsafe-paths "$patch_file"
changed=$(git -C "$work" diff --name-only)
[ "$changed" = "etc/nginx/conf.d/default.conf" ] || {
  echo "patch modifies unauthorized files: $changed" >&2
  exit 1
}
docker create --name "$fixed_container" "$image" >/dev/null
docker cp "$work/etc/nginx/conf.d/default.conf" "$fixed_container:/etc/nginx/conf.d/default.conf"
docker start "$fixed_container" >/dev/null
ready=0
for _ in $(seq 1 30); do
  if docker exec "$fixed_container" nginx -t >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  docker logs "$fixed_container" >&2 || true
  exit 1
fi
docker exec -i "$fixed_container" bash -s < "$(cd "$(dirname "$0")" && pwd)/f2p.sh"
docker exec -i "$fixed_container" bash -s < "$(cd "$(dirname "$0")" && pwd)/p2p.sh"
