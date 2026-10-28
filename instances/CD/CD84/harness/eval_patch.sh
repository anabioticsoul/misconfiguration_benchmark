#!/usr/bin/env bash
set -euo pipefail
[ "$#" -ge 1 ] && [ "$#" -le 2 ]
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
image="${2:-cd84:latest}"
root="$(mktemp -d "${TMPDIR:-/tmp}/cd84-eval.XXXXXX")"
container="cd84-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/etc"
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 60); do
  if docker exec "$container" test -f /etc/my.cnf; then break; fi
  sleep 1
done
docker cp "$container:/etc/my.cnf" "$root/etc/my.cnf"
printf 'baseline\n' >"$root/.git-commit"
(
  cd "$root"
  git init -q
  git config user.email evaluator@localhost
  git config user.name evaluator
  git add etc/my.cnf
  git commit -q -m baseline
  git apply --unsafe-paths "$patch_file"
  changed="$(git diff --name-only)"
  [ "$changed" = "etc/my.cnf" ]
)
docker cp "$root/etc/my.cnf" "$container:/etc/my.cnf"
docker rm -f "$container" >/dev/null
container=""
docker run -d --name "cd84-eval-fixed-$$" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
container="cd84-eval-fixed-$$"
for _ in $(seq 1 60); do
  if docker exec "$container" test -f /etc/my.cnf; then break; fi
  sleep 1
done
docker cp "$root/etc/my.cnf" "$container:/etc/my.cnf"
docker exec "$container" bash -s <"$script_dir/f2p.sh"
docker exec "$container" bash -s <"$script_dir/p2p.sh"
echo 'CD84 patch evaluation passed.'
