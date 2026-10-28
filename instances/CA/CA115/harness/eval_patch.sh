#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: eval_patch.sh <prediction-patch> [image-name]" >&2
  exit 2
fi

patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca115:latest}"
script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
stage="$(mktemp -d "${TMPDIR:-/tmp}/ca115-eval.XXXXXX")"
fault_id=""
fixed_id=""

cleanup() {
  if [ -n "$fault_id" ]; then docker rm -f "$fault_id" >/dev/null 2>&1 || :; fi
  if [ -n "$fixed_id" ]; then docker rm -f "$fixed_id" >/dev/null 2>&1 || :; fi
  rm -rf "$stage"
}
trap cleanup EXIT HUP INT TERM

[ -f "$patch_file" ] || { echo "patch file not found" >&2; exit 2; }
command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 2; }

fault_id="$(docker create "$image")"
mkdir -p "$stage/opt/ca115"
docker cp "$fault_id:/opt/ca115/app.php" "$stage/opt/ca115/"

cd "$stage"
git init -q
 git add -- opt/ca115/app.php

paths="$(awk '/^(---|\+\+\+) / { p=$2; sub(/^[ab]\//, "", p); sub(/\t.*$/, "", p); print p }' "$patch_file")"
[ -n "$paths" ] || { echo "patch has no file headers" >&2; exit 1; }
grep -Fq 'error_reporting' "$patch_file" || {
  echo "patch does not modify required option: error_reporting" >&2
  exit 1
}
while IFS= read -r path; do
  [ "$path" = "opt/ca115/app.php" ] || {
    echo "patch modifies forbidden path: $path" >&2
    exit 1
  }
done <<EOF
$paths
EOF

# The patch protocol intentionally applies the prediction with unsafe paths enabled.
git apply --check --unsafe-paths "$patch_file"
git apply --unsafe-paths "$patch_file"

fixed_id="$(docker create "$image" /bin/bash -lc 'exec tail -f /dev/null')"
docker cp "$stage/opt/ca115/app.php" "$fixed_id:/opt/ca115/"
docker start "$fixed_id" >/dev/null

ready=0
attempt=0
while [ "$attempt" -lt 60 ]; do
  if docker exec "$fixed_id" /bin/bash -lc 'test -f /opt/ca115/app.php && command -v php >/dev/null 2>&1'; then
    ready=1
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$ready" -eq 1 ] || { echo "repaired container did not become ready" >&2; exit 1; }

docker exec -i "$fixed_id" /bin/bash < "$script_dir/f2p.sh"
docker exec -i "$fixed_id" /bin/bash < "$script_dir/p2p.sh"
