#!/usr/bin/env bash
set -euo pipefail
runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -o '-h 127.0.0.1' -w start >/dev/null
trap "runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -m fast stop >/dev/null || true" EXIT
out=$(mktemp)
err=$(mktemp)
trap 'rm -f "$out" "$err"; runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -m fast stop >/dev/null || true' EXIT
set +e
PGCLIENTENCODING=WIN1252 LC_ALL=C PAGER=cat psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres postgres -c 'SELEC 1;' >"$out" 2>"$err"
status=$?
set -e
cat "$out" "$err"
test "$status" -ne 0
! grep -F 'character with byte sequence' "$out" "$err" >/dev/null
grep -E 'syntax error|syntax' "$out" "$err" >/dev/null
rm -f "$out" "$err"
