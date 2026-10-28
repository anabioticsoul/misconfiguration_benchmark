#!/usr/bin/env bash
set -euo pipefail

nginx_log=/tmp/cb83-repro-nginx.log
apache_log=/tmp/cb83-repro-apache.log
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
    if curl --silent --show-error --fail http://127.0.0.1/health >/tmp/cb83-repro-health 2>/dev/null; then
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
for _ in $(seq 1 50); do
    apache_state=$(ps -o stat= -p "$apache_pid" 2>/dev/null || true)
    if [ -z "$apache_state" ]; then
        break
    fi
    case "$apache_state" in
        Z*) break ;;
    esac
    sleep 0.2
done
apache_state=$(ps -o stat= -p "$apache_pid" 2>/dev/null || true)
if [ -n "$apache_state" ]; then
    case "$apache_state" in
        Z*) ;;
        *)
            echo 'Apache unexpectedly remained running despite the port conflict.' >&2
            cat "$apache_log" >&2
            exit 1
            ;;
    esac
fi
set +e
wait "$apache_pid"
apache_status=$?
set -e
apache_output=$(cat "$apache_log")
printf '%s\n' "$apache_output" >&2
if [ "$apache_status" -eq 0 ]; then
    echo 'Apache exited successfully despite the expected listener conflict.' >&2
    exit 1
fi
case "$apache_output" in
    *'could not bind to address'*) ;;
    *)
        echo 'Apache output did not contain the expected bind failure.' >&2
        exit 1
        ;;
esac
