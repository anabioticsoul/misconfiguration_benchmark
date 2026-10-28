#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca21:latest}"
root="$(mktemp -d)"
container="ca21-eval-$RANDOM"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/opt/ca21/src/main/resources"
printf 'baseline\n' > "$root/.gitmsg"
git -C "$root" init -q
git -C "$root" config user.email openhands@all-hands.dev
git -C "$root" config user.name openhands

docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/opt/ca21/src/main/resources/applicationContext.xml" "$root/opt/ca21/src/main/resources/applicationContext.xml"
git -C "$root" add . && git -C "$root" commit -q -m baseline
( cd "$root" && git apply --unsafe-paths "$patch_file" )
[ "$(git -C "$root" diff --name-only)" = "opt/ca21/src/main/resources/applicationContext.xml" ]
docker cp "$root/opt/ca21/src/main/resources/applicationContext.xml" "$container:/opt/ca21/src/main/resources/applicationContext.xml"
docker exec -i "$container" bash -s < "$(cd "$(dirname "$0")" && pwd)/f2p.sh"
docker exec -i "$container" bash -s < "$(cd "$(dirname "$0")" && pwd)/p2p.sh"
