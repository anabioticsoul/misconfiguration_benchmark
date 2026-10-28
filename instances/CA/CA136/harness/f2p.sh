#!/usr/bin/env bash
set -euo pipefail
stop_services() { for pidfile in /run/php/php8.2-fpm.pid /run/php/php-fpm.pid /var/run/nginx.pid; do if test -s "$pidfile"; then pid=$(cat "$pidfile"); case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" >/dev/null 2>&1 || true ;; esac; fi; done; }
stop_services
php-fpm8.2 -F >/tmp/ca136-fpm.log 2>&1 &
fpm_pid=$!
nginx
cleanup() { nginx -s quit >/dev/null 2>&1 || true; kill "$fpm_pid" >/dev/null 2>&1 || true; wait "$fpm_pid" >/dev/null 2>&1 || true; for _ in $(seq 1 30); do kill -0 "$fpm_pid" >/dev/null 2>&1 || break; done; }
trap cleanup EXIT
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8080/ >/tmp/ca136-f2p.out 2>/dev/null; then break; fi
done
grep -qx 'CA136 PHP application OK' /tmp/ca136-f2p.out
