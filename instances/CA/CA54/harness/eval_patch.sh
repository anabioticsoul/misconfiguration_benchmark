#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca54:latest}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
root="$(mktemp -d)"
source_container="ca54-eval-source-$$"
patched_container="ca54-eval-patched-$$"
cleanup() {
  docker rm -f "$source_container" "$patched_container" >/dev/null 2>&1 || true
  rm -rf "$root"
}
trap cleanup EXIT
mkdir -p "$root/opt/hadoop/etc/hadoop"

docker run -d --name "$source_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
copied=false
for _ in $(seq 1 60); do
  if docker cp "$source_container:/opt/hadoop/etc/hadoop/core-site.xml" "$root/opt/hadoop/etc/hadoop/core-site.xml"; then
    copied=true
    break
  fi
  sleep 1
done
[ "$copied" = true ]
git -C "$root" init -q
git -C "$root" config user.email evaluator@misconfigbench.local
git -C "$root" config user.name evaluator
git -C "$root" add .
git -C "$root" commit -qm baseline
GIT_CONFIG_NOSYSTEM=1 git -C "$root" apply --unsafe-paths "$patch_file"
[ "$(git -C "$root" diff --name-only)" = "opt/hadoop/etc/hadoop/core-site.xml" ]
docker rm -f "$source_container" >/dev/null
docker run -d --name "$patched_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
ready=false
for _ in $(seq 1 60); do
  if docker exec "$patched_container" test -f /opt/hadoop/etc/hadoop/core-site.xml; then
    ready=true
    break
  fi
  sleep 1
done
[ "$ready" = true ]
docker cp "$root/opt/hadoop/etc/hadoop/core-site.xml" "$patched_container:/opt/hadoop/etc/hadoop/core-site.xml"
docker exec "$patched_container" bash -s < "$script_dir/f2p.sh"
docker exec "$patched_container" bash -s < "$script_dir/p2p.sh"
