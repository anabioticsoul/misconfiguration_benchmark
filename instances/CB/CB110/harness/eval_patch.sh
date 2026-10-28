#!/usr/bin/env bash
set -euo pipefail
[ "$#" -ge 1 ] && [ "$#" -le 2 ]
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb110:latest}"
work="$(mktemp -d)"
container=''
cleanup() {
  if [ -n "$container" ]; then docker rm -f "$container" >/dev/null 2>&1 || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/etc/nginx/conf.d"
container="$(docker create "$image")"
docker cp "$container:/etc/nginx/conf.d/default.conf" "$work/etc/nginx/conf.d/default.conf"
docker rm "$container" >/dev/null
container=''
case "$patch_file" in /*) ;; *) exit 1 ;; esac
headers="$(grep '^diff --git ' "$patch_file" || true)"
[ -n "$headers" ]
while IFS= read -r header; do
  [ "$header" = 'diff --git a/etc/nginx/conf.d/default.conf b/etc/nginx/conf.d/default.conf' ]
done <<EOF
$headers
EOF
git -C "$work" apply --unsafe-paths "$patch_file"
container="$(docker run -d --entrypoint /bin/bash "$image" -lc "python3 /usr/local/bin/jenkins-backend.py >/tmp/backend.log 2>&1 & exec nginx -g 'daemon off;'")"
for _ in $(seq 1 60); do
  if docker exec "$container" test -f /etc/nginx/conf.d/default.conf; then break; fi
  sleep 1
done
docker cp "$work/etc/nginx/conf.d/default.conf" "$container:/etc/nginx/conf.d/default.conf"
docker exec "$container" nginx -s reload >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  if docker exec "$container" curl --fail --silent http://127.0.0.1/jenkins >/dev/null 2>&1; then break; fi
  sleep 1
done
docker exec "$container" curl --fail --silent http://127.0.0.1/jenkins | grep -F 'Jenkins proxy is healthy' >/dev/null
docker exec "$container" nginx -t >/dev/null 2>&1
