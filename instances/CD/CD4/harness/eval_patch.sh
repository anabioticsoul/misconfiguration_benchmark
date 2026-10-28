#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd4:latest}"
self_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/cd4-eval.XXXXXX")"
faulty="cd4-eval-faulty-$$"
patched="cd4-eval-patched-$$"
cleanup() {
  docker rm -f "$faulty" "$patched" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT INT TERM

mkdir -p "$work/etc/mysql/conf.d"
docker run -d --name "$faulty" "$image" runtime >/dev/null
for _ in $(seq 1 120); do
  if docker exec "$faulty" test -f /run/cd4-ready >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
if ! docker exec "$faulty" test -f /run/cd4-ready >/dev/null 2>&1; then
  docker logs "$faulty" >&2 || true
  exit 1
fi
docker cp "$faulty:/etc/mysql/conf.d/cd4-fault.cnf" "$work/etc/mysql/conf.d/cd4-fault.cnf"

cd "$work"
git init -q
git config user.name "openhands"
git config user.email "openhands@all-hands.dev"
git add etc/mysql/conf.d/cd4-fault.cnf
git commit -q -m baseline
git apply --unsafe-paths "$patch_file"
changed=$(git diff --name-only)
if [ "$changed" != "etc/mysql/conf.d/cd4-fault.cnf" ]; then
  echo "prediction modifies files outside the allowed configuration file" >&2
  printf '%s\n' "$changed" >&2
  exit 1
fi
if ! git diff --quiet -- etc/mysql/conf.d/cd4-fault.cnf; then
  :
else
  echo "prediction does not modify the required configuration" >&2
  exit 1
fi

# The bind-mounted repaired file is read during startup of a new container.
docker run -d --name "$patched" \
  -v "$work/etc/mysql/conf.d/cd4-fault.cnf:/etc/mysql/conf.d/cd4-fault.cnf:ro" \
  "$image" runtime >/dev/null
for _ in $(seq 1 120); do
  if docker exec "$patched" test -f /run/cd4-ready >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
if ! docker exec "$patched" test -f /run/cd4-ready >/dev/null 2>&1; then
  docker logs "$patched" >&2 || true
  exit 1
fi

docker cp "$self_dir/f2p.sh" "$patched:/tmp/cd4-f2p.sh"
docker cp "$self_dir/p2p.sh" "$patched:/tmp/cd4-p2p.sh"
docker exec "$patched" bash /tmp/cd4-f2p.sh
docker exec "$patched" bash /tmp/cd4-p2p.sh
