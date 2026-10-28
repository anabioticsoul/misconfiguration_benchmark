#!/usr/bin/env bash
set -euo pipefail

nginx_log=/tmp/cb83-f2p-nginx.log
apache_log=/tmp/cb83-f2p-apache.log
nginx_pid=''
apache_pid=''

cleanup() {
    if [ -n "$apache_pid" ] && kill -0 "$apache_pid" 2>/dev/null; then
        kill "$apache_pid" 2>/dev/null || true
        wait "$apache_pid" 2>/dev/null || true
    fi
    if [ -n "$nginx_pid" ] && kill -0 "$nginx_pid" 2>/dev/null; then
        kill "$nginx_pid" 2>/dev/null || true
        wait "$nginx_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

: >"$nginx_log"
: >"$apache_log"
nginx -t
nginx -g 'daemon off;' >"$nginx_log" 2>&1 &
nginx_pid=$!
nginx_ready=0
for _ in $(seq 1 40); do
    if curl --silent --show-error --fail http://127.0.0.1/health >/tmp/cb83-f2p-health 2>/dev/null; then
        nginx_ready=1
        break
    fi
    nginx_state=$(ps -o stat= -p "$nginx_pid" 2>/dev/null || true)
    if [ -z "$nginx_state" ]; then
        break
    fi
    case "$nginx_state" in
        Z*) break ;;
    esac
    sleep 0.2
done
if [ "$nginx_ready" -ne 1 ]; then
    echo 'nginx did not become ready.' >&2
    cat "$nginx_log" >&2
    exit 1
fi

apache2ctl -DFOREGROUND >"$apache_log" 2>&1 &
apache_pid=$!
apache_ready=0
for _ in $(seq 1 50); do
    if curl --silent --show-error --fail http://127.0.0.1:8080/ >/tmp/cb83-f2p-apache-response 2>/dev/null; then
        apache_ready=1
        break
    fi
    apache_state=$(ps -o stat= -p "$apache_pid" 2>/dev/null || true)
    if [ -z "$apache_state" ]; then
        break
    fi
    case "$apache_state" in
        Z*) break ;;
    esac
    sleep 0.2
done
if [ "$apache_ready" -ne 1 ]; then
    echo 'Apache did not become ready on port 8080.' >&2
    cat "$apache_log" >&2
    cat "$nginx_log" >&2
    exit 1
fi

if ! curl --silent --show-error --fail http://127.0.0.1/ >/tmp/cb83-f2p-proxy-response 2>/dev/null; then
    echo 'nginx could not proxy a request to Apache.' >&2
    cat "$nginx_log" >&2
    cat "$apache_log" >&2
    exit 1
fi
response=$(cat /tmp/cb83-f2p-proxy-response)
case "$response" in
    *apache-ok*) ;;
    *)
        echo 'nginx did not proxy the request to Apache.' >&2
        printf '%s\n' "$response" >&2
        exit 1
        ;;
esac
