#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca107:latest}"
root="$(mktemp -d)"
old_container="ca107-old-$$"
new_container="ca107-new-$$"
cleanup() {
  docker rm -f "$old_container" "$new_container" >/dev/null 2>&1 || true
  rm -rf "$root"
}
trap cleanup EXIT

docker create --name "$old_container" "$image" >/dev/null
docker cp "$old_container:/etc/nginx/nginx.conf" "$root/nginx.conf"
mkdir -p "$root/etc/nginx"
cp "$root/nginx.conf" "$root/etc/nginx/nginx.conf"
cd "$root"
git init -q
 git config user.email evaluator@example.invalid
 git config user.name evaluator
 git add etc/nginx/nginx.conf
 git commit -q -m baseline
if ! git apply --unsafe-paths --check "$patch_file"; then
  echo "prediction patch does not apply" >&2
  exit 1
fi
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
[ "$changed" = "etc/nginx/nginx.conf" ] || {
  echo "patch modifies files outside /etc/nginx/nginx.conf" >&2
  exit 1
}
docker create --name "$new_container" "$image" >/dev/null
docker cp "$root/etc/nginx/nginx.conf" "$new_container:/etc/nginx/nginx.conf"
docker start "$new_container" >/dev/null
for _ in 1 2 3 4 5; do
  if docker exec "$new_container" nginx -t >/dev/null 2>&1; then break; fi
  sleep 1
done
docker exec "$new_container" nginx -t >/dev/null
docker exec "$new_container" bash -s < "$(cd "$(dirname "$0")" && pwd)/f2p.sh"
docker exec "$new_container" bash -s < "$(cd "$(dirname "$0")" && pwd)/p2p.sh"
