#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  printf 'usage: %s <prediction-patch> [image-name]\n' "$0" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb162:latest}"
self_dir="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/cb162-eval.XXXXXX")"
source_container="cb162-source-$$"
container="cb162-eval-$$"
cleanup() {
  docker rm -f "$source_container" "$container" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/opt/cb162/config"
docker run -d --name "$source_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do
  if docker exec "$source_container" test -f /opt/cb162/READY >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! docker exec "$source_container" test -f /opt/cb162/READY >/dev/null 2>&1; then
  printf '%s\n' "faulty container did not become ready" >&2
  exit 1
fi
docker cp "$source_container:/opt/cb162/config/config.exs" "$work/opt/cb162/config/config.exs"
docker rm -f "$source_container" >/dev/null
cd "$work"
git init -q
git config user.name evaluator
git config user.email evaluator@localhost
git add opt/cb162/config/config.exs
git commit -q -m baseline
if ! git apply --unsafe-paths "$patch_file"; then
  printf '%s\n' "prediction patch did not apply" >&2
  exit 1
fi
changed="$(git diff --name-only)"
if [ "$changed" != "opt/cb162/config/config.exs" ]; then
  printf '%s\n' "patch changed files outside the allowed configuration" >&2
  printf '%s\n' "$changed" >&2
  exit 1
fi
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do
  if docker exec "$container" test -f /opt/cb162/READY >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! docker exec "$container" test -f /opt/cb162/READY >/dev/null 2>&1; then
  printf '%s\n' "patched container did not become ready" >&2
  exit 1
fi
docker cp "$work/opt/cb162/config/config.exs" "$container:/opt/cb162/config/config.exs"
docker cp "$self_dir/f2p.sh" "$container:/tmp/cb162-f2p.sh"
docker cp "$self_dir/p2p.sh" "$container:/tmp/cb162-p2p.sh"
docker exec "$container" chmod +x /tmp/cb162-f2p.sh /tmp/cb162-p2p.sh
docker exec "$container" /tmp/cb162-f2p.sh
docker exec "$container" /tmp/cb162-p2p.sh
