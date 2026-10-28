#!/usr/bin/env bash
set -euo pipefail

patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd81:latest}"
root="$(cd "$(dirname "$0")" && pwd)"
name="cd81-eval-fault-$$"
fixed_name="cd81-eval-fixed-$$"
work="$(mktemp -d)"
cleanup() {
  docker rm -f "$name" "$fixed_name" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

docker create --name "$name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$name" >/dev/null
for _ in $(seq 1 60); do
  if docker exec "$name" test -f /etc/profile.d/cd81-locale.sh; then break; fi
  sleep 1
done
mkdir -p "$work/etc/profile.d"
docker cp "$name":/etc/profile.d/cd81-locale.sh "$work/etc/profile.d/cd81-locale.sh"
git -C "$work" init -q
git -C "$work" config user.name evaluator
git -C "$work" config user.email evaluator@example.invalid
git -C "$work" add etc/profile.d/cd81-locale.sh
git -C "$work" commit -q -m baseline
cp "$patch_file" "$work/prediction.diff"
git -C "$work" apply --unsafe-paths "$work/prediction.diff"
changed=$(git -C "$work" diff --name-only)
[ "$changed" = "etc/profile.d/cd81-locale.sh" ]
docker create --name "$fixed_name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$fixed_name" >/dev/null
for _ in $(seq 1 60); do
  if docker exec "$fixed_name" test -f /etc/profile.d/cd81-locale.sh; then break; fi
  sleep 1
done
docker cp "$work/etc/profile.d/cd81-locale.sh" "$fixed_name":/etc/profile.d/cd81-locale.sh
if ! docker exec -i "$fixed_name" bash -s <"$root/f2p.sh" >"$work/f2p.log" 2>&1; then
  cat "$work/f2p.log"
  exit 1
fi
if ! docker exec -i "$fixed_name" bash -s <"$root/p2p.sh" >"$work/p2p.log" 2>&1; then
  cat "$work/p2p.log"
  exit 1
fi
