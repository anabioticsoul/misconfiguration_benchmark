#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd103:latest}"
root="$(mktemp -d)"
container="cd103-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
docker create --name "$container" "$image" >/dev/null
mkdir -p "$root/etc/nginx/conf.d"
docker cp "$container:/etc/nginx/conf.d/drupal.conf" "$root/etc/nginx/conf.d/drupal.conf"
printf 'baseline\n' > "$root/.gitkeep"
git -C "$root" init -q
git -C "$root" add .
git -C "$root" -c user.name=bench -c user.email=bench@example.test commit -qm baseline
(cd "$root" && git apply --unsafe-paths "$patch_file")
changed="$(git -C "$root" diff --name-only)"
test "$changed" = "etc/nginx/conf.d/drupal.conf"
docker cp "$root/etc/nginx/conf.d/drupal.conf" "$container:/etc/nginx/conf.d/drupal.conf"
docker start "$container" >/dev/null
# docker create/start uses the source image command, not instance runtime metadata.
if ! docker exec "$container" bash -lc 'php-fpm8.2 -D' >"$root/php-fpm-start.log" 2>&1; then
  cat "$root/php-fpm-start.log" >&2
  exit 1
fi
for i in $(seq 1 60); do
  if docker exec "$container" curl -sS http://127.0.0.1/index.php >/tmp/cd103-eval-body 2>/dev/null; then break; fi
  sleep 1
done
if ! docker exec "$container" curl -sS http://127.0.0.1/index.php >/tmp/cd103-eval-body 2>"$root/readiness-error.log"; then
  cat "$root/php-fpm-start.log" >&2
  cat "$root/readiness-error.log" >&2
  exit 1
fi
harness_dir="$(cd "$(dirname "$0")" && pwd)"
docker cp "$harness_dir/f2p.sh" "$container:/tmp/f2p.sh"
docker cp "$harness_dir/p2p.sh" "$container:/tmp/p2p.sh"
docker exec "$container" bash /tmp/f2p.sh
docker exec "$container" bash /tmp/p2p.sh
