#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca11:latest}"
root="$(cd "$(dirname "$0")/.." && pwd)"
stage="$(mktemp -d)"
container="ca11-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$stage"; }
trap cleanup EXIT
mkdir -p "$stage/opt/ca11"
printf 'baseline\n' > "$stage/.git_marker"
git -C "$stage" init -q
git -C "$stage" config user.email openhands@all-hands.dev
git -C "$stage" config user.name openhands
docker create --name "$container" --entrypoint java "$image" -jar /opt/ca11/app.jar --spring.config.additional-location=file:/opt/ca11/ >/dev/null
docker cp "$container:/opt/ca11/application.properties" "$stage/opt/ca11/application.properties"
git -C "$stage" add . && git -C "$stage" commit -qm baseline
git -C "$stage" apply --unsafe-paths "$patch_file"
[ "$(git -C "$stage" diff --name-only)" = "opt/ca11/application.properties" ]
# Deliver only the allowed configuration file to a fresh container.
docker cp "$stage/opt/ca11/application.properties" "$container:/opt/ca11/application.properties"
docker start "$container" >/dev/null
docker exec -i "$container" bash -s < "$root/harness/f2p.sh" || { docker logs "$container" >&2; exit 1; }
docker exec -i "$container" bash -s < "$root/harness/p2p.sh" || { docker logs "$container" >&2; exit 1; }
