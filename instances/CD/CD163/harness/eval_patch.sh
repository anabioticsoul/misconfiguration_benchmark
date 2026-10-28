#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd163:latest}"
self_dir="$(cd "$(dirname "$0")" && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/cd163-eval.XXXXXX")"
container_id=""
patched_id=""
cleanup() {
  if [ -n "$container_id" ]; then docker rm -f "$container_id" >/dev/null 2>&1 || true; fi
  if [ -n "$patched_id" ]; then docker rm -f "$patched_id" >/dev/null 2>&1 || true; fi
  rm -rf "$workdir"
}
trap cleanup EXIT
mkdir -p "$workdir/staging/etc/apache2/sites-available"
container_id="$(docker create "$image")"
docker cp "$container_id:/etc/apache2/sites-available/cd163.conf" "$workdir/staging/etc/apache2/sites-available/cd163.conf"
docker rm "$container_id" >/dev/null
container_id=""
cd "$workdir/staging"
git init -q
git config user.name openhands
git config user.email openhands@all-hands.dev
git add etc/apache2/sites-available/cd163.conf
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
if [ "$changed" != "etc/apache2/sites-available/cd163.conf" ]; then
  echo "patch changed files outside the allowed configuration target:" >&2
  printf '%s\n' "$changed" >&2
  exit 1
fi
patched_id="$(docker create --entrypoint /usr/local/bin/cd163-entrypoint.sh "$image" /bin/bash)"
docker cp "$workdir/staging/etc/apache2/sites-available/cd163.conf" "$patched_id:/etc/apache2/sites-available/cd163.conf"
docker start "$patched_id" >/dev/null
for attempt in $(seq 1 60); do
  if docker exec "$patched_id" curl -fsS http://127.0.0.1/health.php >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" -eq 60 ]; then
    echo "patched container did not become ready" >&2
    docker logs "$patched_id" >&2 || true
    docker exec "$patched_id" cat /var/log/cd163/php-server.log >&2 || true
    exit 1
  fi
  sleep 1
done
docker exec "$patched_id" bash -s < "$self_dir/f2p.sh"
docker exec "$patched_id" bash -s < "$self_dir/p2p.sh"
