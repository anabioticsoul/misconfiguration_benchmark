#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  printf 'usage: %s <prediction-patch> [image-name]\n' "$0" >&2
  exit 2
fi

patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd100:latest}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/cd100-eval.XXXXXX")"
fault_container="cd100-eval-fault-$$"
fixed_container="cd100-eval-fixed-$$"
cleanup() {
  docker rm -f "$fault_container" "$fixed_container" >/dev/null 2>&1 || true
  rm -rf "$workdir"
}
trap cleanup EXIT

if [ ! -f "$patch_file" ]; then
  printf 'prediction patch does not exist: %s\n' "$patch_file" >&2
  exit 1
fi

docker create --name "$fault_container" "$image" >/dev/null
docker cp "$fault_container:/root/.config/Code/User/settings.json" "$workdir/settings.json"
docker rm "$fault_container" >/dev/null
fault_container="cd100-eval-fault-removed-$$"

mkdir -p "$workdir/stage/root/.config/Code/User"
cp "$workdir/settings.json" "$workdir/stage/root/.config/Code/User/settings.json"
(
  cd "$workdir/stage"
  git init -q
  git config user.name "openhands"
  git config user.email "openhands@all-hands.dev"
  git add root/.config/Code/User/settings.json
  git commit -q -m baseline
  git apply --unsafe-paths "$patch_file"
  modified="$(git diff --name-only)"
  if [ "$modified" != "root/.config/Code/User/settings.json" ]; then
    printf 'patch modified disallowed files or no files: %s\n' "$modified" >&2
    exit 1
  fi
)

docker create --name "$fixed_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$workdir/stage/root/.config/Code/User/settings.json" "$fixed_container:/root/.config/Code/User/settings.json"
docker start "$fixed_container" >/dev/null
ready=0
for _ in $(seq 1 60); do
  if docker exec "$fixed_container" test -f /root/.config/Code/User/settings.json; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  printf '%s\n' "repaired container did not become ready" >&2
  docker logs "$fixed_container" >&2 || true
  exit 1
fi

docker exec -i "$fixed_container" bash -s < "$script_dir/f2p.sh"
docker exec -i "$fixed_container" bash -s < "$script_dir/p2p.sh"
