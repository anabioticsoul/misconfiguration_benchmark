#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf '%s\n' 'usage: eval_patch.sh <prediction-patch> [image-name]' >&2
    exit 2
fi

patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd218:latest}"
target='etc/php/8.1/cli/conf.d/99-xdebug.ini'
absolute_target="/etc/php/8.1/cli/conf.d/99-xdebug.ini"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/cd218-eval.XXXXXX")"
fault_container=''
run_container=''

cleanup() {
    if [ -n "$run_container" ]; then docker rm -f "$run_container" > /dev/null 2>&1 || true; fi
    if [ -n "$fault_container" ]; then docker rm "$fault_container" > /dev/null 2>&1 || true; fi
    rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$workdir/etc/php/8.1/cli/conf.d"
fault_container="$(docker create "$image")"
docker cp "$fault_container:$absolute_target" "$workdir/$target"
docker rm "$fault_container" > /dev/null
fault_container=''

cd "$workdir"
git init -q
git config user.name openhands
git config user.email openhands@all-hands.dev
git add "$target"
git commit -q -m baseline

git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
if [ "$changed" != "$target" ]; then
    printf '%s\n' 'Prediction modifies files outside the allowed configuration target.' >&2
    printf '%s\n' "$changed" >&2
    exit 1
fi
if ! grep -F 'xdebug.mode=debug' "$target" > /dev/null; then
    printf '%s\n' 'Prediction does not enable Xdebug debugger mode.' >&2
    exit 1
fi

run_container="$(docker run -d --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null')"
for attempt in $(seq 1 60); do
    if docker exec "$run_container" test -f "$absolute_target"; then
        break
    fi
    if [ "$attempt" -eq 60 ]; then
        printf '%s\n' 'Container did not become ready.' >&2
        docker logs "$run_container" >&2 || true
        exit 1
    fi
    sleep 1
done

docker cp "$workdir/$target" "$run_container:$absolute_target"
docker exec "$run_container" bash -s < "$script_dir/f2p.sh"
docker exec "$run_container" bash -s < "$script_dir/p2p.sh"
