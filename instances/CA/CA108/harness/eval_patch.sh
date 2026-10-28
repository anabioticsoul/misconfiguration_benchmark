#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca108:latest}"
work="$(mktemp -d)"
name="ca108_eval_$$"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
docker create --name "$name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$name:/etc/nginx/nginx.conf" "$work/nginx.conf"
awk '/^diff --git / {print $3}' "$patch_file" | sed 's#^a/##' | sort -u >"$work/changed"
printf '%s\n' etc/nginx/nginx.conf >"$work/allowed"
diff -u "$work/allowed" "$work/changed"
mkdir -p "$work/etc/nginx"
cp "$work/nginx.conf" "$work/etc/nginx/nginx.conf"
git -C "$work" init -q
git -C "$work" apply --unsafe-paths "$patch_file"
docker cp "$work/etc/nginx/nginx.conf" "$name:/etc/nginx/nginx.conf"
docker start "$name" >/dev/null
docker exec "$name" nginx -t >/dev/null
docker exec "$name" bash -lc '/usr/local/bin/upstream.py >/tmp/upstream.log 2>&1 & u=$!; nginx -g "daemon off;" >/tmp/nginx.log 2>&1 & n=$!; trap "kill $n $u 2>/dev/null || true" EXIT; for i in $(seq 1 50); do curl -fsS http://127.0.0.1:8081/127.0.0.1:8443/hello >/tmp/probe 2>/dev/null && break; done; grep -Fx "upstream HTTPS content" /tmp/probe'
