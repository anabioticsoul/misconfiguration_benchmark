#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca147:latest}"
work="$(mktemp -d)"
container="ca147-eval-$$"
new_container=""
cleanup() { docker rm -f "$container" "$new_container" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/etc/php/8.1/cli"
docker create --name "$container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/etc/php/8.1/cli/php.ini" "$work/etc/php/8.1/cli/php.ini"
(cd "$work" && git init -q && git config user.email eval@example.invalid && git config user.name evaluator && git add . && git commit -qm baseline)
if ! (cd "$work" && git apply --unsafe-paths "$patch_file"); then
  echo 'prediction patch did not apply' >&2
  exit 1
fi
changed=$(cd "$work" && git diff --name-only)
[ "$changed" = "etc/php/8.1/cli/php.ini" ]
new_container="${container}-patched"
docker rm -f "$container" >/dev/null 2>&1 || true
docker create --name "$new_container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$work/etc/php/8.1/cli/php.ini" "$new_container:/etc/php/8.1/cli/php.ini"
docker start "$new_container" >/dev/null
for _ in $(seq 1 30); do docker exec "$new_container" test -f /etc/php/8.1/cli/php.ini && break; sleep 1; done
configured=$(docker exec "$new_container" awk -F= '/^[[:space:]]*html_errors[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print tolower($2); exit}' /etc/php/8.1/cli/php.ini)
effective=$(docker exec "$new_container" php -r 'echo ini_get("html_errors") ? "on" : "off";')
[ "$configured" = "$effective" ]
docker exec "$new_container" php -i | grep -F 'Loaded Configuration File => /etc/php/8.1/cli/php.ini' >/dev/null
[ "$(docker exec "$new_container" php -r 'echo 2 + 2;')" = "4" ]
harness_dir=$(cd "$(dirname "$0")" && pwd)
docker exec -i "$new_container" bash < "$harness_dir/f2p.sh"
docker exec -i "$new_container" bash < "$harness_dir/p2p.sh"
