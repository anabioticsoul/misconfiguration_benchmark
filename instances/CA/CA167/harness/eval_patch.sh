#!/usr/bin/env bash
set -euo pipefail

harness_dir="$(cd "$(dirname "$0")" && pwd)"
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca167:latest}"
work="$(mktemp -d "${TMPDIR:-/tmp}/ca167-eval.XXXXXX")"
container="ca167-eval-$$"
patched="ca167-eval-patched-$$"
cleanup() {
  docker rm -f "$container" "$patched" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/etc/apache2"
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/etc/apache2/ports.conf" "$work/etc/apache2/ports.conf"

git -C "$work" init -q
git -C "$work" config user.email evaluator@localhost
git -C "$work" config user.name evaluator
git -C "$work" add etc/apache2/ports.conf
git -C "$work" commit -qm baseline
( cd "$work" && git apply --unsafe-paths "$patch_file" )
changed="$(git -C "$work" diff --name-only)"
[ "$changed" = "etc/apache2/ports.conf" ]
docker rm -f "$container" >/dev/null

docker run -d --name "$patched" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$work/etc/apache2/ports.conf" "$patched:/etc/apache2/ports.conf"
docker exec "$patched" bash -lc 'apachectl configtest'
docker exec "$patched" bash -lc 'test -f /etc/apache2/ports.conf && test -f /etc/apache2/sites-enabled/000-default.conf'
docker exec "$patched" bash -lc 'apachectl -k start; trap "apachectl -k stop >/dev/null 2>&1 || true" EXIT; response="$(curl --noproxy "*" --connect-timeout 3 -sS http://127.0.0.1/)"; printf "%s" "$response" | grep -F "Apache2 Ubuntu Default Page" >/dev/null || printf "%s" "$response" | grep -F "It works!" >/dev/null'
docker exec "$patched" bash -lc 'bash -s' < "$harness_dir/p2p.sh"
docker exec "$patched" bash -lc 'bash -s' < "$harness_dir/f2p.sh"
