#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd107:latest}"
CD107_HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
root="$(mktemp -d)"
trap 'docker rm -f cd107-eval-$$ >/dev/null 2>&1 || true; rm -rf "$root"' EXIT
mkdir -p "$root/stage/opt/cd107"
docker create --name cd107-eval-$$ "$image" >/dev/null
docker cp cd107-eval-$$:/opt/cd107/application.properties "$root/stage/opt/cd107/application.properties"
docker rm cd107-eval-$$ >/dev/null
cd "$root/stage"
git init -q
git config user.email evaluator@localhost
git config user.name evaluator
git add opt/cd107/application.properties && git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
test "$changed" = opt/cd107/application.properties
# Validate both oracle harnesses in a fresh container with only the repaired file delivered.
docker run --rm --name cd107-eval-$$ -v "$PWD/opt/cd107/application.properties:/opt/cd107/application.properties:ro" -v "$CD107_HARNESS_DIR/f2p.sh:/harness/f2p.sh:ro" -v "$CD107_HARNESS_DIR/p2p.sh:/harness/p2p.sh:ro" "$image" bash -lc 'bash /harness/p2p.sh && bash /harness/f2p.sh'
