#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca170:latest}"
root="$(mktemp -d)"
name="ca170-eval-$$"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/var/lib/postgresql/data"
git -C "$root" init -q
docker run -d --name "$name" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
ready=0
for _ in $(seq 1 30); do
  if docker exec "$name" test -f /var/lib/postgresql/data/postgresql.conf; then ready=1; break; fi
  sleep 1
done
test "$ready" -eq 1
docker cp "$name:/var/lib/postgresql/data/postgresql.conf" "$root/var/lib/postgresql/data/postgresql.conf"
test -s "$root/var/lib/postgresql/data/postgresql.conf"
allowed='var/lib/postgresql/data/postgresql.conf'
case "$patch_file" in *.diff|*.patch) ;; *) echo 'patch must be unified diff' >&2; exit 1;; esac
while IFS= read -r line; do
  case "$line" in
    '+++ '*) path=${line#+++ }; path=${path#b/}; path=${path%%$'\t'*}; test "$path" = "$allowed" || { echo "forbidden patch path: $path" >&2; exit 1; } ;;
    '--- '*) path=${line#--- }; path=${path#a/}; path=${path%%$'\t'*}; test "$path" = "$allowed" || { echo "forbidden patch path: $path" >&2; exit 1; } ;;
  esac
done < "$patch_file"
git -C "$root" apply --unsafe-paths "$patch_file"
docker cp "$root/var/lib/postgresql/data/postgresql.conf" "$name:/var/lib/postgresql/data/postgresql.conf"
docker exec "$name" bash -lc 'runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -o "-h 127.0.0.1" -w start >/dev/null; trap "runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -m fast stop >/dev/null || true" EXIT; out=$(mktemp); err=$(mktemp); set +e; PGCLIENTENCODING=WIN1252 LC_ALL=C PAGER=cat psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres postgres -c "SELEC 1;" >"$out" 2>"$err"; s=$?; set -e; cat "$out" "$err"; test "$s" -ne 0; ! grep -F "character with byte sequence" "$out" "$err" >/dev/null; grep -E "syntax error|syntax" "$out" "$err" >/dev/null'
docker exec "$name" bash -lc 'runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -m fast stop >/dev/null || true'
docker exec "$name" bash -lc 'runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -o "-h 127.0.0.1" -w start >/dev/null; trap "runuser -u postgres -- /usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data -m fast stop >/dev/null || true" EXIT; result=$(PGCLIENTENCODING=WIN1252 LC_ALL=C PAGER=cat psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres postgres -c "SELECT 1;" 2>&1); printf "%s\\n" "$result"; printf "%s\\n" "$result" | grep -F "(1 row)" >/dev/null'
