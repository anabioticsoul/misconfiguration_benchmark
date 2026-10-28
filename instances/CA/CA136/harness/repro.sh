#!/usr/bin/env bash
set -euo pipefail
stop_services() { for pidfile in /run/php/php8.2-fpm.pid /run/php/php-fpm.pid /var/run/nginx.pid; do if test -s "$pidfile"; then pid=$(cat "$pidfile"); case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" >/dev/null 2>&1 || true ;; esac; fi; done; }
stop_services
php-fpm8.2 -F >/tmp/ca136-fpm.log 2>&1 &
fpm_pid=$!
nginx
cleanup() { nginx -s quit >/dev/null 2>&1 || true; kill "$fpm_pid" >/dev/null 2>&1 || true; wait "$fpm_pid" >/dev/null 2>&1 || true; for _ in $(seq 1 30); do kill -0 "$fpm_pid" >/dev/null 2>&1 || break; done; }
trap cleanup EXIT
http_status=""
for _ in $(seq 1 30); do
  http_status="$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/ || true)"
  [ "$http_status" = "404" ] && break
  sleep 0.1
done
[ "$http_status" = "404" ] || {
  echo "expected FastCGI script-path failure (HTTP 404), got HTTP $http_status" >&2
  exit 1
}
out=$(mktemp)
status=0
curl -fsS http://127.0.0.1:8080/ >"$out" 2>&1 || status=$?
grep -q '404' "$out" || { cat "$out"; rm -f "$out"; exit 1; }
test "$status" -ne 0
rm -f "$out"
