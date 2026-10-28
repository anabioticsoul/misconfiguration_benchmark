#!/usr/bin/env bash
set -euo pipefail

patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
script_dir="$(cd "$(dirname "$0")" && pwd)"
image="${2:-ca144:latest}"
root="$(mktemp -d)"
old_cid="ca144-old-$$"
new_cid="ca144-new-$$"
cleanup() {
  docker rm -f "$old_cid" "$new_cid" >/dev/null 2>&1 || true
  rm -rf "$root"
}
trap cleanup EXIT

mkdir -p "$root/etc/nginx/conf.d"
docker create --name "$old_cid" "$image" >/dev/null
docker cp "$old_cid:/etc/nginx/conf.d/default.conf" "$root/etc/nginx/conf.d/default.conf"
cp "$root/etc/nginx/conf.d/default.conf" "$root/original.conf"

git -C "$root" init -q
git -C "$root" config user.email evaluator@localhost
git -C "$root" config user.name evaluator
git -C "$root" add etc/nginx/conf.d/default.conf
git -C "$root" commit -qm baseline
git -C "$root" apply --unsafe-paths "$patch_file"
if test "$(git -C "$root" diff --name-only | wc -l | tr -d ' ')" -ne 1 ||
   test "$(git -C "$root" diff --name-only)" != "etc/nginx/conf.d/default.conf"; then
  echo 'Patch modifies files outside the allowed Nginx configuration' >&2
  exit 1
fi

docker run -d --name "$new_cid" "$image" >/dev/null
docker cp "$root/etc/nginx/conf.d/default.conf" "$new_cid:/etc/nginx/conf.d/default.conf"
docker exec "$new_cid" nginx -s reload >/dev/null 2>&1 ||
  docker exec "$new_cid" nginx >/dev/null 2>&1
docker exec "$new_cid" bash -s < "$script_dir/f2p.sh"
docker exec "$new_cid" bash -s < "$script_dir/p2p.sh"
