#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: eval_patch.sh <prediction-patch> [image-name]" >&2
    exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd170:latest}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/cd170-eval.XXXXXX")"
source_cid=""
test_cid=""
cleanup() {
    if [ -n "$source_cid" ]; then docker rm -f "$source_cid" >/dev/null 2>&1 || true; fi
    if [ -n "$test_cid" ]; then docker rm -f "$test_cid" >/dev/null 2>&1 || true; fi
    rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/opt/cd170"
source_cid="$(docker create "$image")"
docker cp "$source_cid:/opt/cd170/requirements.txt" "$work/opt/cd170/requirements.txt"
docker rm "$source_cid" >/dev/null
source_cid=""

cd "$work"
git init -q
git config user.name "openhands"
git config user.email "openhands@all-hands.dev"
git add opt/cd170/requirements.txt
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
if [ "$changed" != "opt/cd170/requirements.txt" ]; then
    echo "patch modified files outside opt/cd170/requirements.txt" >&2
    printf '%s\n' "$changed" >&2
    exit 1
fi
patch_diff="$(git diff -- opt/cd170/requirements.txt)"
if ! grep -Fq '+psycopg2==2.4.4' <<<"$patch_diff"; then
    echo "patch did not add the required psycopg2 dependency" >&2
    exit 1
fi

test_cid="$(docker create "$image" /bin/bash -lc 'exec tail -f /dev/null')"
docker start "$test_cid" >/dev/null
ready=0
for _ in $(seq 1 60); do
    if docker exec "$test_cid" test -f /opt/cd170/requirements.txt; then
        ready=1
        break
    fi
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    echo "container did not become ready" >&2
    docker logs "$test_cid" >&2 || true
    exit 1
fi
docker cp "$work/opt/cd170/requirements.txt" "$test_cid:/opt/cd170/requirements.txt"
docker cp "$script_dir/f2p.sh" "$test_cid:/tmp/cd170-f2p.sh"
docker cp "$script_dir/p2p.sh" "$test_cid:/tmp/cd170-p2p.sh"
docker exec "$test_cid" bash /tmp/cd170-f2p.sh
docker exec "$test_cid" bash /tmp/cd170-p2p.sh
