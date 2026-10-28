#!/usr/bin/env bash
set -euo pipefail
log=$(mktemp)
trap 'rm -f "$log"' EXIT
set +e
vim -Nu /root/.vimrc -n -es -V1"$log" -c 'qa!' >/dev/null 2>&1
status=$?
set -e
cat "$log" >&2
if [ "$status" -eq 0 ] || ! grep -Eq 'E(15|488):' "$log"; then
  echo 'expected Vim to reject the faulty mapleader assignment' >&2
  exit 1
fi
