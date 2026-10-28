#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then echo "usage: $0 <patch> [image]" >&2; exit 2; fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca159:latest}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
container="ca159-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/etc/apache2"
docker run --name "$container" -d "$image" /bin/bash -lc 'exec tail -f /dev/null' >/dev/null
ready=0
for _ in $(seq 1 30); do
  if docker exec "$container" test -f /etc/apache2/loadbalancer.conf; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then echo 'container did not become ready' >&2; exit 1; fi
docker cp "$container:/etc/apache2/loadbalancer.conf" "$work/etc/apache2/loadbalancer.conf"
( cd "$work" && git init -q && git config user.email evaluator@example.invalid && git config user.name evaluator && git add . && git commit -qm baseline )
git -C "$work" apply --unsafe-paths "$patch_file"
if git -C "$work" diff --name-only baseline | grep -v '^etc/apache2/loadbalancer.conf$' | grep .; then echo 'patch changed forbidden files' >&2; exit 1; fi
docker cp "$work/etc/apache2/loadbalancer.conf" "$container:/etc/apache2/loadbalancer.conf"
docker exec "$container" apache2ctl -f /etc/apache2/ca159.conf -k start >/dev/null
started=0
for _ in $(seq 1 30); do
  if docker exec "$container" test -f /var/run/apache2/ca159.pid; then started=1; break; fi
  sleep 1
done
if [ "$started" -ne 1 ]; then echo 'Apache did not start' >&2; exit 1; fi
docker cp "$script_dir/f2p.sh" "$container:/tmp/f2p.sh"
docker cp "$script_dir/p2p.sh" "$container:/tmp/p2p.sh"
docker exec "$container" bash /tmp/f2p.sh
docker exec "$container" bash /tmp/p2p.sh
