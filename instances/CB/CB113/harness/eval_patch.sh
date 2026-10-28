#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb113:latest}"
root="$(mktemp -d)"
container="cb113-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/etc/profile.d"
docker run -d --name "$container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/etc/profile.d/java_home.sh" "$root/etc/profile.d/java_home.sh"
( cd "$root" && git init -q && git config user.email evaluator@example.invalid && git config user.name evaluator && git add . && git commit -qm baseline && git apply --unsafe-paths "$patch_file" )
changed=$(cd "$root" && git diff --name-only)
[[ "$changed" == "etc/profile.d/java_home.sh" ]]
expected=$(cat "$root/etc/profile.d/java_home.sh")
[[ "$expected" == *'JAVA_HOME='* ]]
docker rm -f "$container" >/dev/null
container="cb113-eval-fixed-$$"
docker run -d --name "$container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$root/etc/profile.d/java_home.sh" "$container:/etc/profile.d/java_home.sh"
docker exec "$container" bash -lc 'source /etc/profile.d/java_home.sh && /usr/local/bin/java-home-check' >/dev/null
docker exec "$container" bash -lc 'java -version' >/dev/null 2>&1
