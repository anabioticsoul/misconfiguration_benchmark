#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
image="${2:-cb150:latest}"
root="$(mktemp -d)"
container="cb150-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
docker create --name "$container" "$image" >/dev/null
docker cp "$container:/etc/nginx/conf.d/fastcgi.conf" "$root/fastcgi.conf"
mkdir -p "$root/etc/nginx/conf.d"
cp "$root/fastcgi.conf" "$root/etc/nginx/conf.d/fastcgi.conf"
(cd "$root" && git init -q && git add etc/nginx/conf.d/fastcgi.conf && git commit -qm baseline && git apply --unsafe-paths "$patch_file")
if [ "$(cd "$root" && git diff --name-only)" != "etc/nginx/conf.d/fastcgi.conf" ]; then
    echo 'patch modifies files outside the allowed configuration' >&2
    exit 1
fi
docker cp "$root/etc/nginx/conf.d/fastcgi.conf" "$container:/etc/nginx/conf.d/fastcgi.conf"
docker cp "$script_dir/f2p.sh" "$container:/tmp/f2p.sh"
docker cp "$script_dir/p2p.sh" "$container:/tmp/p2p.sh"
docker start "$container" >/dev/null
docker exec "$container" bash /tmp/f2p.sh
docker exec "$container" bash /tmp/p2p.sh
