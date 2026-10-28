#!/usr/bin/env bash
set -euo pipefail
rm -f /var/log/nginx/error.log /var/run/nginx.pid
php-fpm8.2 -F >/tmp/cb150-fpm.log 2>&1 &
fpm_pid=$!
nginx -c /etc/nginx/nginx.conf -g 'daemon off;' >/tmp/cb150-nginx.log 2>&1 &
nginx_pid=$!
cleanup() { kill "$nginx_pid" "$fpm_pid" 2>/dev/null || true; }
trap cleanup EXIT
code=000
for _ in $(seq 1 60); do
    code=$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/index.php || true)
    [ "$code" = "200" ] && break
    kill -0 "$nginx_pid" 2>/dev/null || break
    sleep 0.1
done
[ "$code" = "200" ]
curl -sS -o /tmp/cb150-f2p-body http://127.0.0.1:8080/index.php
[ "$(wc -c < /tmp/cb150-f2p-body | tr -d ' ')" -ge 20000000 ]
# Exercise the temp-file path as well as the normal response path. A client
# that does not drain the response makes Nginx buffer the FastCGI body on disk.
: > /var/log/nginx/error.log
bash -c 'exec 3<>/dev/tcp/127.0.0.1/8080; printf "GET /index.php HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n" >&3; sleep 2' &
client_pid=$!
sleep 1
wait "$client_pid" || true
! grep -F 'Permission denied' /var/log/nginx/error.log >/dev/null
