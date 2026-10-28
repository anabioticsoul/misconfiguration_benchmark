#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb146:latest}"
work="$(mktemp -d)"
container="cb146-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/opt/laravel/config"
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 60); do docker exec "$container" test -f /opt/laravel/config/database.php && break; sleep 1; done
docker cp "$container:/opt/laravel/config/database.php" "$work/opt/laravel/config/database.php"
(cd "$work" && git init -q && git add . && git commit -qm baseline && git apply --unsafe-paths "$patch_file")
changed=$(cd "$work" && git diff --name-only)
[ "$changed" = "opt/laravel/config/database.php" ]
grep -F '/var/run/mysqld/mysqld.sock' "$work/opt/laravel/config/database.php" >/dev/null
docker cp "$work/opt/laravel/config/database.php" "$container:/opt/laravel/config/database.php"
docker cp "$script_dir/repro.sh" "$container:/tmp/repro.sh"
docker cp "$script_dir/f2p.sh" "$container:/tmp/f2p.sh"
docker cp "$script_dir/p2p.sh" "$container:/tmp/p2p.sh"
docker exec "$container" bash /tmp/repro.sh >/dev/null 2>&1 || true
docker exec "$container" bash /tmp/f2p.sh
docker exec "$container" bash /tmp/p2p.sh
