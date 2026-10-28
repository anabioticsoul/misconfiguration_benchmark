#!/usr/bin/env bash
set -euo pipefail

OUTPUT="$(mysql --no-defaults -uroot '-pca35\spass' -N -B -e 'SELECT 1;' 2>/tmp/ca14-p2p.err)"
if [ "$OUTPUT" != "1" ]; then
  echo "[FAIL] Explicit authenticated query failed: $OUTPUT"
  cat /tmp/ca14-p2p.err
  exit 1
fi
echo "[PASS] p2p: MySQL service remains healthy."
