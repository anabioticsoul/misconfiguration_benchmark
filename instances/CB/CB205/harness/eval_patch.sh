#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb205:latest}"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
cleanup() { docker rm -f cb205-eval-fault cb205-eval-fixed >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap cleanup EXIT
mkdir -p "$tmp/etc/apache2"
docker run -d --name cb205-eval-fault --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do docker exec cb205-eval-fault test -f /etc/apache2/ports.conf && break; sleep 1; done
docker cp cb205-eval-fault:/etc/apache2/ports.conf "$tmp/etc/apache2/ports.conf"
cd "$tmp"
git init -q
git config user.email openhands@all-hands.dev
git config user.name openhands
git add .
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
[ "$changed" = "etc/apache2/ports.conf" ]
docker cp "$tmp/etc/apache2/ports.conf" cb205-eval-fault:/etc/apache2/ports.conf
docker rm -f cb205-eval-fault >/dev/null

docker run -d --name cb205-eval-fixed --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do docker exec cb205-eval-fixed test -x /usr/sbin/apache2 && break; sleep 1; done
docker cp "$tmp/etc/apache2/ports.conf" cb205-eval-fixed:/etc/apache2/ports.conf
docker exec -i cb205-eval-fixed bash -s < "$root/harness/f2p.sh"
docker exec -i cb205-eval-fixed bash -s < "$root/harness/p2p.sh"
