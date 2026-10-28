#!/usr/bin/env bash
set -euo pipefail
[ "$#" -ge 1 ] && [ "$#" -le 2 ]
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca1:latest}"
command -v docker >/dev/null
command -v git >/dev/null
stage="$(mktemp -d)"
old_cid=""
new_cid=""
cleanup() {
  [ -z "$old_cid" ] || docker rm -f "$old_cid" >/dev/null 2>&1 || true
  [ -z "$new_cid" ] || docker rm -f "$new_cid" >/dev/null 2>&1 || true
  rm -rf "$stage"
}
trap cleanup EXIT
mkdir -p "$stage/etc/mysql/conf.d"
printf '[mysqld]\nquery_cache_size-128M\n' > "$stage/etc/mysql/conf.d/fault.cnf"
old_cid="$(docker run -d --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null')"
for _ in $(seq 1 30); do
  if docker exec "$old_cid" test -f /etc/mysql/conf.d/fault.cnf; then
    break
  fi
  sleep 1
done
docker cp "$old_cid:/etc/mysql/conf.d/fault.cnf" "$stage/etc/mysql/conf.d/fault.cnf"
header_count="$(grep -Ec '^(--- a/|\+\+\+ b/)' "$patch_file")"
[ "$header_count" -eq 2 ] || {
  echo 'patch scope is not limited to fault.cnf' >&2
  exit 1
}
grep -Fx -- '--- a/etc/mysql/conf.d/fault.cnf' "$patch_file" >/dev/null
grep -Fx -- '+++ b/etc/mysql/conf.d/fault.cnf' "$patch_file" >/dev/null
(
  cd "$stage"
  git apply --check --unsafe-paths "$patch_file"
  git apply --unsafe-paths "$patch_file"
)
new_cid="$(docker run -d --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null')"
for _ in $(seq 1 30); do
  if docker exec "$new_cid" test -f /etc/mysql/conf.d/fault.cnf; then
    break
  fi
  sleep 1
done
docker cp "$stage/etc/mysql/conf.d/fault.cnf" "$new_cid:/etc/mysql/conf.d/fault.cnf"
docker exec -i "$new_cid" bash -s < "$(cd "$(dirname "$0")" && pwd)/f2p.sh"
docker exec -i "$new_cid" bash -s < "$(cd "$(dirname "$0")" && pwd)/p2p.sh"
