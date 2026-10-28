#!/usr/bin/env bash
set -euo pipefail
rm -f /var/log/nginx/error.log /var/run/nginx.pid
php-fpm8.2 -F >/tmp/cb150-fpm.log 2>&1 &
fpm_pid=$!
nginx -t -c /etc/nginx/nginx.conf >/tmp/cb150-nginx-test.log 2>&1
nginx -c /etc/nginx/nginx.conf -g 'daemon off;' >/tmp/cb150-nginx.log 2>&1 &
nginx_pid=$!
cleanup() { kill "$nginx_pid" "$fpm_pid" 2>/dev/null || true; }
trap cleanup EXIT
sleep 1
# Keep the response socket unread so Nginx must spill the buffered FastCGI
# response to fastcgi_temp_path instead of forwarding it directly to curl.
bash -c 'exec 3<>/dev/tcp/127.0.0.1/8080; printf "GET /index.php HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n" >&3; sleep 2' &
client_pid=$!
sleep 1
wait "$client_pid" || true
if grep -F 'Permission denied' /var/log/nginx/error.log >/dev/null 2>&1 && grep -F 'while reading upstream' /var/log/nginx/error.log >/dev/null 2>&1; then
    exit 0
fi
printf 'expected FastCGI temporary-file permission failure\n' >&2
cat /tmp/cb150-nginx-test.log /tmp/cb150-nginx.log /var/log/nginx/error.log 2>/dev/null >&2 || true
exit 1
