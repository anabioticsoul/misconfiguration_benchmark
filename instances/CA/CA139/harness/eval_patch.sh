#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    echo "usage: $0 <prediction-patch> [image-name]" >&2
    exit 2
fi

patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca139:latest}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
work_dir="$(mktemp -d)"
fault_container="ca139-eval-fault-$$"
fixed_container="ca139-eval-fixed-$$"

cleanup() {
    docker rm -f "$fault_container" "$fixed_container" >/dev/null 2>&1 || true
    rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$work_dir/var/www/html/config/etc/php7/conf.d"
docker create --name "$fault_container" --entrypoint /bin/bash "$image" \
    -lc "exec tail -f /dev/null" >/dev/null
docker cp "$fault_container:/var/www/html/config/etc/php7/conf.d/php.ini" \
    "$work_dir/var/www/html/config/etc/php7/conf.d/php.ini" >/dev/null
docker start "$fault_container" >/dev/null

git -C "$work_dir" init -q
git -C "$work_dir" config user.name "openhands-evaluator"
git -C "$work_dir" config user.email "openhands-evaluator@example.invalid"
git -C "$work_dir" add -A
git -C "$work_dir" commit -q -m baseline

git -C "$work_dir" apply --unsafe-paths "$patch_file"
git -C "$work_dir" add -N -- var/www/html/.ddev/php/memlimit.ini
changed="$(git -C "$work_dir" diff --name-only)"
if [[ "$changed" != "var/www/html/.ddev/php/memlimit.ini" ]]; then
    echo "prediction changes files outside the allowed configuration target:" >&2
    printf '%s\n' "$changed" >&2
    exit 1
fi

test -f "$work_dir/var/www/html/.ddev/php/memlimit.ini"
docker rm -f "$fault_container" >/dev/null
docker create --name "$fixed_container" --entrypoint /bin/bash "$image" \
    -lc "exec tail -f /dev/null" >/dev/null
docker start "$fixed_container" >/dev/null
docker exec "$fixed_container" mkdir -p /var/www/html/.ddev/php
docker cp "$work_dir/var/www/html/.ddev/php/memlimit.ini" \
    "$fixed_container:/var/www/html/.ddev/php/memlimit.ini" >/dev/null

for attempt in 1 2 3 4 5 6; do
    if docker exec "$fixed_container" test -f /var/www/html/.ddev/php/memlimit.ini; then
        break
    fi
    if [[ "$attempt" -eq 6 ]]; then
        echo "fixed container did not become ready" >&2
        exit 1
    fi
    sleep 1
done

docker exec -i "$fixed_container" bash -s < "$script_dir/f2p.sh"
docker exec -i "$fixed_container" bash -s < "$script_dir/p2p.sh"
