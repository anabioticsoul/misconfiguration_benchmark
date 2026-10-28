#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: $0 <prediction-patch> [image-name]" >&2
    exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd89:latest}"
self_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/cd89-eval.XXXXXX")"
container="cd89-eval-$$"
patched_container="cd89-eval-patched-$$"
cleanup() {
    docker rm -f "$container" "$patched_container" >/dev/null 2>&1 || true
    rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

mkdir -p "$work_dir/opt/cd89"
docker create --name "$container" "$image" >/dev/null
docker cp "$container:/opt/cd89/log4j2.xml" "$work_dir/opt/cd89/log4j2.xml"
cd "$work_dir"
git init -q
git config user.name "openhands"
git config user.email "openhands@all-hands.dev"
git add opt/cd89/log4j2.xml
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed=$(git diff --name-only)
if [ "$changed" != "opt/cd89/log4j2.xml" ]; then
    echo "patch modifies files outside /opt/cd89/log4j2.xml" >&2
    printf '%s\n' "$changed" >&2
    exit 1
fi
git diff --quiet -- opt/cd89/log4j2.xml && {
    echo "patch does not modify the required configuration option" >&2
    exit 1
}

docker create --name "$patched_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp opt/cd89/log4j2.xml "$patched_container:/opt/cd89/log4j2.xml"
docker start "$patched_container" >/dev/null
ready=0
for _ in $(seq 1 60); do
    if [ "$(docker inspect -f '{{.State.Running}}' "$patched_container")" != true ]; then
        docker logs "$patched_container" >&2 || true
        echo "patched container exited before readiness" >&2
        exit 1
    fi
    if docker exec "$patched_container" test -f /opt/cd89/log4j2.xml; then
        ready=1
        break
    fi
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    echo "patched container did not become ready" >&2
    docker logs "$patched_container" >&2 || true
    exit 1
fi
docker exec "$patched_container" bash -lc "$(sed -n '1,$p' "$self_dir/f2p.sh")"
docker exec "$patched_container" bash -lc "$(sed -n '1,$p' "$self_dir/p2p.sh")"
