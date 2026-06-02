#!/usr/bin/env bash
set -euo pipefail

echo "[CA35] Evaluating MySQL client authentication repair..."

CONFIG_FILE="/etc/mysql/my.cnf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[FAIL] Required MySQL client configuration file is missing."
  exit 1
fi

if grep -qE "^[[:space:]]*password[[:space:]]*=[[:space:]]*CA35'='[[:space:]]*$" "$CONFIG_FILE"; then
  echo "[FAIL] The original faulty client credential entry is still present."
  exit 1
fi

if ! grep -qE "^[[:space:]]*password[[:space:]]*=" "$CONFIG_FILE"; then
  echo "[FAIL] No client password option is present."
  exit 1
fi

echo "[INFO] Running the default MySQL client health check..."

set +e
OUTPUT="$(mysql -N -B -e 'SELECT 1;' 2>&1)"
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]; then
  echo "[FAIL] MySQL client still cannot connect using defaults."
  echo "$OUTPUT"
  exit 1
fi

if ! echo "$OUTPUT" | grep -qx "1"; then
  echo "[FAIL] MySQL command succeeded but returned unexpected output."
  echo "$OUTPUT"
  exit 1
fi

echo "[INFO] Checking that authentication still rejects an invalid password..."

set +e
mysql --no-defaults -uroot -pwrongpass -N -B -e 'SELECT 1;' >/tmp/ca35-negative.out 2>&1
NEG_STATUS=$?
set -e

if [ "$NEG_STATUS" -eq 0 ]; then
  echo "[FAIL] Invalid credentials unexpectedly succeeded."
  exit 1
fi

echo "[PASS] Default MySQL client invocation succeeds without weakening authentication."
