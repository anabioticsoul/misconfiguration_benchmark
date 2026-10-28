#!/usr/bin/env bash
set -euo pipefail

OUTPUT="$(mysql -N -B -e 'SELECT @@global.time_zone;' 2>&1)"
if [ "$OUTPUT" != "Brazil/East" ]; then
  echo "[FAIL] Expected global time zone Brazil/East, got: $OUTPUT"
  exit 1
fi
echo "[PASS] f2p: default client works and server time zone is Brazil/East."
