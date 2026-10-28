#!/usr/bin/env bash
set -euo pipefail

OUTPUT="$(mysql -N -B -e 'SELECT 1;' 2>&1)"

if ! echo "$OUTPUT" | grep -qx "1"; then
  echo "[FAIL] Expected non-interactive default MySQL query to print 1."
  echo "$OUTPUT"
  exit 1
fi

echo "[PASS] f2p: non-interactive default MySQL query succeeded."
