#!/usr/bin/env bash
set -euo pipefail

echo "[CA35] Reproducing MySQL client authentication failure..."
echo "[INFO] Running the default MySQL client health check..."

set +e
OUTPUT="$(mysql -N -B -e 'SELECT 1;' 2>&1)"
STATUS=$?
set -e

echo "$OUTPUT"

if [ "$STATUS" -eq 0 ]; then
  echo "[FAIL] Connection unexpectedly succeeded. The case may already be fixed."
  exit 1
fi

if echo "$OUTPUT" | grep -q "ERROR 1045"; then
  echo "[PASS] Reproduced expected symptom: MySQL access denied."
  exit 0
fi

echo "[FAIL] MySQL failed, but not with expected ERROR 1045."
exit 1
