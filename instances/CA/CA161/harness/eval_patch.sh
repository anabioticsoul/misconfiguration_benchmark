#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca161:latest}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
container="ca161-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/etc/ambari-agent/conf" "$work/etc/yum.repos.d"
docker run --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/tmp/ca161-docker.log 2>&1 &
for _ in $(seq 1 60); do
  running="$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)"
  [[ "$running" == true ]] && break
  sleep 1
done
docker cp "$container:/etc/ambari-agent/conf/ambari-agent.ini" "$work/etc/ambari-agent/conf/ambari-agent.ini"
docker cp "$container:/etc/yum.repos.d/HDP.repo" "$work/etc/yum.repos.d/HDP.repo"
cd "$work"
git init -q
git config user.name openhands
git config user.email openhands@all-hands.dev
git add .
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
[[ "$(git diff --name-only)" == "etc/ambari-agent/conf/ambari-agent.ini" ]]
docker cp "$work/etc/ambari-agent/conf/ambari-agent.ini" "$container:/etc/ambari-agent/conf/ambari-agent.ini"
docker exec -i "$container" bash -s < "$root/harness/f2p.sh"
docker exec -i "$container" bash -s < "$root/harness/p2p.sh"
