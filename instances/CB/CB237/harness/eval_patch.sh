#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb237:latest}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/cb237-eval.XXXXXX")"
faulty="cb237-eval-faulty-$$"
repaired="cb237-eval-repaired-$$"
cleanup() {
  docker rm -f "$faulty" "$repaired" >/dev/null 2>&1 || true
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$work_dir/opt/cb237"
docker create --name "$faulty" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$faulty" >/dev/null
for _ in $(seq 1 60); do
  if docker exec "$faulty" /bin/bash -lc 'test -f /opt/cb237/pg_service.conf'; then
    break
  fi
  sleep 1
done
docker exec "$faulty" /bin/bash -lc 'test -f /opt/cb237/pg_service.conf'
docker cp "$faulty:/opt/cb237/pg_service.conf" "$work_dir/opt/cb237/pg_service.conf"

cd "$work_dir"
git init -q
git config user.name openhands
git config user.email openhands@all-hands.dev
git add opt/cb237/pg_service.conf
git commit -q -m baseline
git apply --unsafe-paths "$patch_file"
modified=$(git diff --name-only)
[ "$modified" = "opt/cb237/pg_service.conf" ]
git diff --quiet -- opt/cb237/pg_service.conf && {
  echo "prediction did not modify the required option" >&2
  exit 1
}

docker create --name "$repaired" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$repaired" >/dev/null
for _ in $(seq 1 60); do
  if docker exec "$repaired" /bin/bash -lc 'test -f /opt/cb237/pg_service.conf'; then
    break
  fi
  sleep 1
done
docker exec "$repaired" /bin/bash -lc 'test -f /opt/cb237/pg_service.conf'
docker cp "$work_dir/opt/cb237/pg_service.conf" "$repaired:/opt/cb237/pg_service.conf"
docker cp "$script_dir/f2p.sh" "$repaired:/tmp/cb237-f2p.sh"
docker cp "$script_dir/p2p.sh" "$repaired:/tmp/cb237-p2p.sh"
docker exec "$repaired" /bin/bash -lc 'chmod +x /tmp/cb237-f2p.sh /tmp/cb237-p2p.sh'
docker exec "$repaired" /bin/bash -lc /tmp/cb237-f2p.sh
docker exec "$repaired" /bin/bash -lc /tmp/cb237-p2p.sh
