#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca136:latest}"
script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
root="$(mktemp -d)"
container="ca136-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT

docker create --name "$container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/etc/nginx/conf.d/default.conf" "$root/default.conf"
mkdir -p "$root/etc/nginx/conf.d"
cp "$root/default.conf" "$root/etc/nginx/conf.d/default.conf"
(
  cd "$root"
  git init -q
  git config user.email evaluator@example.invalid
  git config user.name evaluator
  git add etc/nginx/conf.d/default.conf
  git commit -qm baseline
  git apply --unsafe-paths "$patch_file"
  test "$(git diff --name-only HEAD)" = "etc/nginx/conf.d/default.conf"
  git diff --unified=0 HEAD -- etc/nginx/conf.d/default.conf | grep -Eq '^\+.*fastcgi_param[[:space:]]+SCRIPT_FILENAME[[:space:]]+'
)
docker rm -f "$container" >/dev/null
docker create --name "$container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$root/etc/nginx/conf.d/default.conf" "$container:/etc/nginx/conf.d/default.conf"
docker start "$container" >/dev/null
ready=1
for _ in $(seq 1 30); do
  if docker exec "$container" test -f /opt/ca136-ready; then ready=0; break; fi
done
test "$ready" -eq 0
docker cp "$script_dir/f2p.sh" "$container:/tmp/ca136-f2p.sh"
docker cp "$script_dir/p2p.sh" "$container:/tmp/ca136-p2p.sh"
docker exec "$container" bash /tmp/ca136-f2p.sh
docker exec "$container" bash /tmp/ca136-p2p.sh
