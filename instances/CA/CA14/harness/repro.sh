#!/usr/bin/env bash
set -euo pipefail

set +e
OUTPUT="$(mysql -N -B -e 'SELECT 1;' 2>&1)"
STATUS=$?
set -e
echo "$OUTPUT"

if [ "$STATUS" -ne 0 ] \
  && echo "$OUTPUT" | grep -q "unknown variable 'time_zone=Brazil/East'"; then
  echo "[PASS] Reproduced the invalid client option."
  exit 0
fi
echo "[FAIL] Expected mysql to reject time_zone=Brazil/East."
exit 1
