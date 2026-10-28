#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s <prediction-patch> [image-name]\n' "$0" >&2
    exit 2
fi

patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd253:latest}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/cd253-eval.XXXXXX")"
fault_container="cd253-fault-$$"
fixed_container="cd253-fixed-$$"
stage="$work_dir/stage"
relative='etc/php/7.4/fpm/pool.d/www.conf'
absolute="/$relative"

cleanup() {
    docker rm -f "$fault_container" >/dev/null 2>&1 || true
    docker rm -f "$fixed_container" >/dev/null 2>&1 || true
    rm -rf "$work_dir"
}
trap cleanup EXIT

[ -f "$patch_file" ]
mkdir -p "$stage/etc/php/7.4/fpm/pool.d"

docker create --name "$fault_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$fault_container" >/dev/null
ready=0
for _ in $(seq 1 30); do
    if docker exec "$fault_container" test -f "$absolute"; then
        ready=1
        break
    fi
    sleep 1
done
[ "$ready" -eq 1 ]
docker cp "$fault_container:$absolute" "$stage/$relative"
docker rm -f "$fault_container" >/dev/null
fault_container=

cd "$stage"
git init -q
git config user.name openhands
git config user.email openhands@all-hands.dev
git add -- "$relative"
git commit -q -m baseline

git apply --unsafe-paths "$patch_file"
changed=$(git diff --name-only)
[ "$changed" = "$relative" ]
[ -z "$(git status --porcelain | awk '$1 == "??" { print $2 }')" ]

mkdir -p "$work_dir/fixed-files/etc/php/7.4/fpm/pool.d"
cp "$stage/$relative" "$work_dir/fixed-files/$relative"

docker create --name "$fixed_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$fixed_container" >/dev/null
ready=0
for _ in $(seq 1 30); do
    if docker exec "$fixed_container" test -f "$absolute"; then
        ready=1
        break
    fi
    sleep 1
done
[ "$ready" -eq 1 ]
docker cp "$work_dir/fixed-files/$relative" "$fixed_container:$absolute"
docker cp "$script_dir/f2p.sh" "$fixed_container:/tmp/cd253-f2p.sh"
docker cp "$script_dir/p2p.sh" "$fixed_container:/tmp/cd253-p2p.sh"
docker exec "$fixed_container" bash /tmp/cd253-f2p.sh
docker exec "$fixed_container" bash /tmp/cd253-p2p.sh
