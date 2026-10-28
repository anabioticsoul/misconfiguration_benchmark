#!/usr/bin/env bash
set -euo pipefail
logdir="/tmp/cb205-p2p"
rm -rf "$logdir"; mkdir -p "$logdir"
cleanup() { nginx -s stop >/dev/null 2>&1 || true; }
trap cleanup EXIT
nginx -t >"$logdir/nginx.log" 2>&1
nginx >>"$logdir/nginx.log" 2>&1
curl -fsS http://127.0.0.1/ >/dev/null
nginx -T >"$logdir/config.log" 2>&1
