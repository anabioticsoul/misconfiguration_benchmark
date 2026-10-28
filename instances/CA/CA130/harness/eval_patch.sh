#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
script_dir="$(cd "$(dirname "$0")" && pwd)"
image="${2:-ca130:latest}"
work="$(mktemp -d)"
container="ca130-eval-$$"
fixed="ca130-fixed-$$"
cleanup() { docker rm -f "$container" "$fixed" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/etc/apache2/sites-available"
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/etc/apache2/sites-available/ca130.conf" "$work/etc/apache2/sites-available/ca130.conf"
cd "$work"
git init -q
git config user.email evaluator@example.test
git config user.name evaluator
git add etc/apache2/sites-available/ca130.conf
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only HEAD)"
[ "$changed" = "etc/apache2/sites-available/ca130.conf" ]
git diff --exit-code -- etc/apache2/sites-available/ca130.conf >/dev/null && exit 1 || true
git diff -- etc/apache2/sites-available/ca130.conf | grep -q 'SSLCertificateFile'
docker run -d --name "$fixed" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do
  docker inspect -f '{{.State.Running}}' "$fixed" 2>/dev/null | grep -q true && break
  sleep 1
done
docker cp "$work/etc/apache2/sites-available/ca130.conf" "$fixed:/etc/apache2/sites-available/ca130.conf"
docker exec "$fixed" bash -s < "$script_dir/f2p.sh"
docker exec "$fixed" bash -s < "$script_dir/p2p.sh"
