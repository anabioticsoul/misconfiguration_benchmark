#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
script_dir="$(cd "$(dirname "$0")" && pwd)"
image="${2:-ca151:latest}"
root="$(mktemp -d)"
container="ca151-extract-$$"
patched="ca151-patched-$$"
cleanup() {
  docker rm -f "$container" "$patched" >/dev/null 2>&1 || true
  rm -rf "$root"
}
trap cleanup EXIT
mkdir -p "$root/etc/mysql/mysql.conf.d"
git init -q "$root"
docker create --name "$container" "$image" >/dev/null
docker cp "$container:/etc/mysql/mysql.conf.d/zz-ca151.cnf" "$root/etc/mysql/mysql.conf.d/zz-ca151.cnf"
printf '%s\n' 'etc/mysql/mysql.conf.d/zz-ca151.cnf' >"$root/allowed"
cd "$root"
git apply --unsafe-paths "$patch_file"
# The applied tree is deliberately limited to the single allowed configuration file.
find "$root" -type f ! -path "$root/allowed" ! -path "$root/etc/mysql/mysql.conf.d/zz-ca151.cnf" ! -path "$root/.git/*" -exec false {} +
docker run -d --name "$patched" "$image" tail -f /dev/null >/dev/null
for _ in $(seq 1 30); do
  docker exec "$patched" test -f /etc/mysql/mysql.conf.d/zz-ca151.cnf && break
  sleep 1
done
docker cp "$root/etc/mysql/mysql.conf.d/zz-ca151.cnf" "$patched:/etc/mysql/mysql.conf.d/zz-ca151.cnf"
docker cp "$script_dir/f2p.sh" "$patched:/tmp/f2p.sh"
docker cp "$script_dir/p2p.sh" "$patched:/tmp/p2p.sh"
docker exec "$patched" bash /tmp/f2p.sh
docker exec "$patched" bash /tmp/p2p.sh
