#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb267:latest}"
harness_dir="$(cd "$(dirname "$0")" && pwd)"
work_dir="$(mktemp -d)"
fault_container="cb267-eval-fault-$$"
patched_container="cb267-eval-patched-$$"

cleanup() {
  docker rm -f "$fault_container" "$patched_container" > /dev/null 2>&1 || true
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$work_dir/etc"
git -C "$work_dir" init -q
git -C "$work_dir" config user.name "openhands"
git -C "$work_dir" config user.email "openhands@all-hands.dev"

docker create --name "$fault_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' > /dev/null
docker cp "$fault_container:/etc/environment" "$work_dir/etc/environment"
docker rm -f "$fault_container" > /dev/null
git -C "$work_dir" add etc/environment
git -C "$work_dir" -c user.name=openhands -c user.email=openhands@all-hands.dev commit -qm baseline

git -C "$work_dir" apply --unsafe-paths "$patch_file"
changed="$(git -C "$work_dir" diff --name-only)"
if [ "$changed" != "etc/environment" ]; then
  echo "Prediction modifies files outside /etc/environment:" >&2
  printf '%s\n' "$changed" >&2
  exit 1
fi

if ! grep -F -x 'LD_LIBRARY_PATH=/opt/php/lib' "$work_dir/etc/environment" > /dev/null; then
  echo "Prediction does not set the required runtime library path" >&2
  exit 1
fi

docker run -d --name "$patched_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' > /dev/null
docker cp "$work_dir/etc/environment" "$patched_container:/etc/environment"

ready=0
i=0
while [ "$i" -lt 60 ]; do
  if docker exec "$patched_container" test -f /etc/environment; then
    ready=1
    break
  fi
  i=$((i + 1))
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "Patched container did not become ready" >&2
  exit 1
fi

docker exec "$patched_container" bash -s < "$harness_dir/f2p.sh"
docker exec "$patched_container" bash -s < "$harness_dir/p2p.sh"
