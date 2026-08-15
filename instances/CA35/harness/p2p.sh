#!/usr/bin/env bash
set -euo pipefail

set +e
mysql --no-defaults -uroot -pwrongpass -N -B -e 'SELECT 1;' >/tmp/ca35-p2p-negative.out 2>&1
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
  echo "[FAIL] Invalid credentials unexpectedly succeeded."
  exit 1
fi

echo "[PASS] p2p: invalid credentials are still rejected."
