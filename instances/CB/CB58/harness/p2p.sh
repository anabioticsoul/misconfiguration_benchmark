#!/usr/bin/env bash
set -euo pipefail

log=/tmp/cb58-p2p-httpd.log
service_log=/opt/apache/logs/error_log
rm -f "$log" "$service_log"
/opt/apache/bin/httpd -DFOREGROUND -f /opt/apache/conf/httpd.conf >"$log" 2>&1 &
server_pid=$!
cleanup() {
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT

ready=0
for _ in $(seq 1 60); do
    if response=$(curl -sS --max-time 1 http://127.0.0.1:8080/ 2>/dev/null); then
        if [[ "$response" == *"Apache CB58 health endpoint"* ]]; then
            ready=1
            break
        fi
    fi
    sleep 1
done
if [[ "$ready" != 1 ]]; then
    cat "$log"
    cat "$service_log" 2>/dev/null || true
    echo "Apache did not become ready" >&2
    exit 1
fi

response=$(curl -fsS --max-time 5 http://127.0.0.1:8080/)
if [[ "$response" != *"Apache CB58 health endpoint"* ]]; then
    cat "$log"
    cat "$service_log" 2>/dev/null || true
    echo "ordinary document request failed" >&2
    exit 1
fi
