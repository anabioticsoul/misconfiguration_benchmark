#!/usr/bin/env bash
set -euo pipefail

log=/tmp/cb162-postgres-f2p.log
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
printf '%s\n' "$output"
if [ "$status" -ne 0 ]; then
  printf '%s\n' "Postgrex SSL connection remained unavailable" >&2
  cat "$log" >&2
  exit 1
fi
case "$output" in
  *"Postgrex SSL connection succeeded"*) exit 0 ;;
  *) printf '%s\n' "successful probe did not report SSL connection" >&2; exit 1 ;;
esac
