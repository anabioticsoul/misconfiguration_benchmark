#!/usr/bin/env bash
set -euo pipefail

if output="$(/opt/flink/bin/checkpoint-probe 2>&1)"; then
    status=0
else
    status=$?
fi
printf '%s\n' "$output"
if [ "$status" -ne 0 ]; then
    printf '%s\n' 'checkpoint operation did not complete after configuration repair' >&2
    exit "$status"
fi
case "$output" in
    *'[checkpoint-probe] checkpoint upload completed'*) ;;
    *)
        printf '%s\n' 'checkpoint completion confirmation was missing' >&2
        exit 1
        ;;
esac
