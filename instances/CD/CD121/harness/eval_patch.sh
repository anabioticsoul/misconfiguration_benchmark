#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd121:latest}"
root="$(mktemp -d)"
container=""
trap 'if [ -n "$container" ]; then docker rm -f "$container" >/dev/null 2>&1 || true; fi; rm -rf "$root"' EXIT
mkdir -p "$root/opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui"
test -n "$image"
container=$(docker create "$image")
docker cp "$container:/opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui/org.eclipse.debug.ui.prefs" "$root/opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui/org.eclipse.debug.ui.prefs"
docker rm "$container" >/dev/null
container=""
git -C "$root" init -q
git -C "$root" add .
git -C "$root" -c user.name=baseline -c user.email=baseline@example.invalid commit -qm baseline
git -C "$root" apply --unsafe-paths "$patch_file"
changed=$(git -C "$root" diff --name-only)
test "$changed" = "opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui/org.eclipse.debug.ui.prefs"
test "$(cat "$root/opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui/org.eclipse.debug.ui.prefs")" = 'filterDeletedProjects=false'
container=$(docker run -d --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null')
docker cp "$root/opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui/org.eclipse.debug.ui.prefs" "$container:/opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui/org.eclipse.debug.ui.prefs"
for harness in f2p.sh p2p.sh; do
  docker cp "$(cd "$(dirname "$0")" && pwd)/$harness" "$container:/tmp/$harness"
  docker exec "$container" bash "/tmp/$harness"
done
