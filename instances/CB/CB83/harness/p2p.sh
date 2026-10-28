#!/usr/bin/env bash
set -euo pipefail

nginx_log=/tmp/cb83-p2p-nginx.log
nginx_pid=''
cleanup() {
    if [ -n "$nginx_pid" ] && kill -0 "$nginx_pid" 2>/dev/null; then
        kill "$nginx_pid" 2>/dev/null || true
        wait "$nginx_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

: >"$nginx_log"
test -x /usr/sbin/nginx
nginx -t
nginx -g 'daemon off;' >"$nginx_log" 2>&1 &
nginx_pid=$!
ready=0
for _ in $(seq 1 40); do
    if curl --silent --show-error --fail http://127.0.0.1/health >/tmp/cb83-p2p-health 2>/dev/null; then
        ready=1
        break
    fi
    if ! kill -0 "$nginx_pid" 2>/dev/null; then
        break
    fi
    sleep 0.2
done
if [ "$ready" -ne 1 ]; then
    echo 'nginx health endpoint did not become ready.' >&2
    cat "$nginx_log" >&2
    exit 1
fi
health=$(cat /tmp/cb83-p2p-health)
[ "$health" = 'nginx-ok' ]
