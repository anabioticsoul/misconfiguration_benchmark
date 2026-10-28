#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca36:latest}"
self_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
work=$(mktemp -d)
container="ca36-eval-$$"
patched="ca36-patched-$$"
cleanup() {
  docker rm -f "$container" "$patched" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/root"
docker create --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$container:/root/.vimrc" "$work/root/.vimrc"
cd "$work"
git init -q
git config user.email evaluator@example.invalid
git config user.name evaluator
git add root/.vimrc
git commit -qm baseline
if ! git apply --unsafe-paths "$patch_file"; then
  echo 'prediction patch does not apply' >&2
  exit 1
fi
changed=$(git diff --name-only)
if [ "$changed" != "root/.vimrc" ]; then
  echo 'prediction modified files outside /root/.vimrc' >&2
  printf '%s\n' "$changed" >&2
  exit 1
fi
docker cp "$work/root/.vimrc" "$container:/root/.vimrc"
docker start "$container" >/dev/null
docker exec -i "$container" bash -s < "$self_dir/f2p.sh"
docker exec -i "$container" bash -s < "$self_dir/p2p.sh"
