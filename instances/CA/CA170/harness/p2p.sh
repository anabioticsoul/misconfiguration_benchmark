#!/usr/bin/env bash
set -euo pipefail
runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -o '-h 127.0.0.1' -w start >/dev/null
trap "runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -m fast stop >/dev/null || true" EXIT
result=$(PGCLIENTENCODING=WIN1252 LC_ALL=C PAGER=cat psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres postgres -c 'SELECT 1;' 2>&1)
printf '%s\n' "$result"
printf '%s\n' "$result" | grep -F '1' >/dev/null
printf '%s\n' "$result" | grep -F '(1 row)' >/dev/null
