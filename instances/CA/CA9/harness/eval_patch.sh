#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca9:latest}"
root="$(mktemp -d)"
container="ca9-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
docker create --name "$container" "$image" >/dev/null
mkdir -p "$root/var/lib/postgresql/data"
docker cp "$container:/var/lib/postgresql/data/postgresql.conf" "$root/var/lib/postgresql/data/postgresql.conf"
git -C "$root" init -q
git -C "$root" add .
git -C "$root" -c user.name=eval -c user.email=eval@example.invalid commit -qm baseline
git -C "$root" apply "$patch_file"
changed=$(git -C "$root" diff --name-only HEAD)
test "$changed" = "var/lib/postgresql/data/postgresql.conf"
docker cp "$root/var/lib/postgresql/data/postgresql.conf" "$container:/var/lib/postgresql/data/postgresql.conf"
docker start "$container" >/dev/null
for _ in $(seq 1 30); do
  if docker exec "$container" pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then break; fi
  sleep 1
done
docker exec "$container" pg_isready -h 127.0.0.1 -p 5432
script_dir="$(cd "$(dirname "$0")" && pwd)"
docker exec -i "$container" bash -s < "$script_dir/f2p.sh"
docker exec -i "$container" bash -s < "$script_dir/p2p.sh"
