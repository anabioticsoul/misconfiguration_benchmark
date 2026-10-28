#!/usr/bin/env bash
set -euo pipefail

url=http://127.0.0.1/static/img/templated/home/img.png
health=http://127.0.0.1/health
log=/home/ubuntu/virtualenv/myapp/error/error.log

ready=0
for _ in $(seq 1 30); do
    if response=$(curl -sS --max-time 2 "$health" 2>&1); then
        if [ "$response" = "healthy" ]; then
            ready=1
            break
        fi
    fi
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    echo "Nginx did not become ready" >&2
    if [ -f "$log" ]; then cat "$log" >&2; fi
    exit 1
fi

if output=$(curl -sS --fail --max-time 5 "$url" 2>&1); then
    echo "Expected static-file request to fail with HTTP 403" >&2
    exit 1
fi
case "$output" in
    *403*) printf '%s\n' "$output"; exit 0 ;;
    *)
        echo "Static-file request failed without the expected 403 symptom" >&2
        printf '%s\n' "$output" >&2
        if [ -f "$log" ]; then cat "$log" >&2; fi
        exit 1
        ;;
esac
