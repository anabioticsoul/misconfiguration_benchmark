#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd152:latest}"
tmp="$(mktemp -d)"
cid=""
patched_cid=""
cleanup() {
  if [ -n "$patched_cid" ]; then docker rm -f "$patched_cid" >/dev/null 2>&1 || true; fi
  if [ -n "$cid" ]; then docker rm -f "$cid" >/dev/null 2>&1 || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/opt/hadoop/etc/hadoop"
cid="$(docker run -d --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null')"
for _ in $(seq 1 30); do
  if docker exec "$cid" test -f /opt/hadoop/etc/hadoop/core-site.xml; then break; fi
  sleep 1
done
docker cp "$cid:/opt/hadoop/etc/hadoop/core-site.xml" "$tmp/opt/hadoop/etc/hadoop/core-site.xml"
(
  cd "$tmp"
  git init -q
  git config user.email evaluator@example.invalid
  git config user.name evaluator
  git add opt/hadoop/etc/hadoop/core-site.xml
  git commit -qm baseline
  git apply --unsafe-paths "$patch_file"
  test "$(git diff --name-only)" = "opt/hadoop/etc/hadoop/core-site.xml"
  git diff --quiet -- opt/hadoop/etc/hadoop/core-site.xml && exit 1 || true
)
patched_cid="$(docker run -d --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null')"
for _ in $(seq 1 30); do
  if docker exec "$patched_cid" test -f /opt/hadoop/etc/hadoop/core-site.xml; then break; fi
  sleep 1
done
docker cp "$tmp/opt/hadoop/etc/hadoop/core-site.xml" "$patched_cid:/opt/hadoop/etc/hadoop/core-site.xml"
docker exec "$patched_cid" bash -s < "$(cd "$(dirname "$0")" && pwd)/../harness/f2p.sh"
docker exec "$patched_cid" bash -s < "$(cd "$(dirname "$0")" && pwd)/../harness/p2p.sh"
docker exec "$patched_cid" bash -s < "$(cd "$(dirname "$0")" && pwd)/../harness/p2p.sh"
