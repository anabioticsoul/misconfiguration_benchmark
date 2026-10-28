#!/usr/bin/env bash
set -euo pipefail

log=/tmp/cb162-postgres-repro.log
: >"$log"
if ! pg_ctlcluster 14 main status >/dev/null 2>&1; then
  if ! pg_ctlcluster 14 main start >"$log" 2>&1; then
    cat "$log" >&2
    exit 1
  fi
fi
for _ in $(seq 1 30); do
  if pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
  cat "$log" >&2
  exit 1
fi

set +e
output=$(cd /opt/cb162/app && MIX_ENV=dev mix run -e 'Cb162Probe.run()' 2>&1)
status=$?
set -e
printf '%s\n' "$output" >&2
if [ "$status" -eq 0 ]; then
  printf '%s\n' "expected the faulty Postgrex SSL connection to fail" >&2
  exit 1
fi
case "$output" in
  *"Postgrex SSL connect failed"*) exit 0 ;;
  *)
    printf '%s\n' "unexpected Postgrex failure output" >&2
    exit 1
    ;;
esac
