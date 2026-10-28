#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cc58:latest}"
harness_dir="$(cd "$(dirname "$0")" && pwd)"
root="$(mktemp -d)"
source_container="cc58-source-$$"
patched_image="cc58-patched-$$"
patched_container="cc58-patched-run-$$"
cleanup() {
  docker rm -f "$source_container" "$patched_container" >/dev/null 2>&1 || true
  docker rmi "$patched_image" >/dev/null 2>&1 || true
  rm -rf "$root"
}
trap cleanup EXIT
mkdir -p "$root/opt/camel"
docker run -d --name "$source_container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$source_container:/opt/camel/pom.xml" "$root/opt/camel/pom.xml"
cd "$root"
git init -q
git config user.email evaluator@example.invalid
git config user.name evaluator
git add opt/camel/pom.xml
git commit -q -m baseline
git apply --unsafe-paths "$patch_file"
[ "$(git diff --name-only)" = "opt/camel/pom.xml" ]
docker commit "$source_container" "$patched_image" >/dev/null
docker rm -f "$source_container" >/dev/null
docker run -d --name "$patched_container" "$patched_image" bash -lc 'exec tail -f /dev/null' >/dev/null

docker exec "$patched_container" mkdir -p /harness
docker cp "$harness_dir/f2p.sh" "$patched_container:/harness/f2p.sh"
docker cp "$harness_dir/p2p.sh" "$patched_container:/harness/p2p.sh"
for _ in $(seq 1 60); do
  if docker exec "$patched_container" test -f /opt/camel/pom.xml; then break; fi
  sleep 1
done
docker cp "$root/opt/camel/pom.xml" "$patched_container:/opt/camel/pom.xml"
docker exec "$patched_container" bash -lc 'cd /opt/camel && bash /harness/f2p.sh'
docker exec "$patched_container" bash -lc 'cd /opt/camel && bash /harness/p2p.sh'
