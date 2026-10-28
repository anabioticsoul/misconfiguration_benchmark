#!/usr/bin/env bash
set -euo pipefail

if output="$(/opt/flink/bin/checkpoint-probe 2>&1)"; then
    status=0
else
    status=$?
fi
printf '%s\n' "$output"
if [ "$status" -eq 0 ]; then
    printf '%s\n' 'expected the checkpoint operation to fail before repair' >&2
    exit 1
fi
case "$output" in
    *'[checkpoint-probe] S3 read timed out'*) ;;
    *)
        printf '%s\n' 'expected the real checkpoint operation to report a read timeout' >&2
        exit 1
        ;;
esac
