#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    echo "usage: $0 <prediction-patch> [image-name]" >&2
    exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb58:latest}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
source_cid=""
patched_cid=""
cleanup() {
    if [[ -n "$source_cid" ]]; then docker rm -f "$source_cid" >/dev/null 2>&1 || true; fi
    if [[ -n "$patched_cid" ]]; then docker rm -f "$patched_cid" >/dev/null 2>&1 || true; fi
    rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/opt/apache/conf"
source_cid="$(docker create "$image")"
docker cp "$source_cid:/opt/apache/conf/httpd.conf" "$work/opt/apache/conf/httpd.conf"
docker rm "$source_cid" >/dev/null
source_cid=""

cd "$work"
git init -q
git config user.name "openhands"
git config user.email "openhands@all-hands.dev"
git add opt/apache/conf/httpd.conf
git commit -qm baseline

git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
if [[ "$changed" != "opt/apache/conf/httpd.conf" ]]; then
    echo "patch modifies files outside /opt/apache/conf/httpd.conf" >&2
    exit 1
fi
if ! grep -Fq "ThreadStackSize 8888888" opt/apache/conf/httpd.conf; then
    echo "patch did not set the required ThreadStackSize value" >&2
    exit 1
fi

git config user.name "openhands"
git config user.email "openhands@all-hands.dev"
git add opt/apache/conf/httpd.conf
git commit -qm repaired

patched_cid="$(docker create --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null')"
docker cp opt/apache/conf/httpd.conf "$patched_cid:/opt/apache/conf/httpd.conf"
docker start "$patched_cid" >/dev/null
for _ in $(seq 1 30); do
    if docker exec "$patched_cid" test -x /opt/apache/bin/httpd && docker exec "$patched_cid" test -f /opt/apache/conf/httpd.conf; then
        break
    fi
    sleep 1
done

docker exec -i "$patched_cid" bash -s < "$script_dir/f2p.sh"
docker exec -i "$patched_cid" bash -s < "$script_dir/p2p.sh"
