#!/usr/bin/env bash
set -euo pipefail

log=/tmp/cb58-f2p-httpd.log
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
    echo "Apache did not become ready" >&2
    exit 1
fi

set +e
probe=$(curl -sS --max-time 5 http://127.0.0.1:8080/stackprobe 2>>"$log")
probe_status=$?
set -e

if grep -Fq "AH00428" "$service_log" && grep -Fq "exited with status" "$service_log"; then
    cat "$log"
    cat "$service_log" 2>/dev/null || true
    echo "stack-sensitive request still crashes the Apache child" >&2
    exit 1
fi

if [[ "$probe_status" -ne 0 || "$probe" != *"stack probe completed"* ]]; then
    cat "$log"
    cat "$service_log" 2>/dev/null || true
    echo "stack-sensitive request did not complete after repair" >&2
    exit 1
fi
