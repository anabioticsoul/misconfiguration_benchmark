#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cd93:latest}"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/etc/mysql/conf.d"
docker run --rm --entrypoint /bin/cat "$image" /etc/mysql/conf.d/fault.cnf > "$work/etc/mysql/conf.d/fault.cnf"
git -C "$work" init -q
git -C "$work" config user.email evaluator@example.invalid
git -C "$work" config user.name evaluator
git -C "$work" add .
git -C "$work" commit -qm baseline
git -C "$work" apply --unsafe-paths "$patch_file"
files=$(git -C "$work" diff --name-only)
[ "$files" = "etc/mysql/conf.d/fault.cnf" ] || { echo "patch modifies forbidden files: $files"; exit 1; }
docker run --rm --entrypoint /bin/bash -v "$work/etc/mysql/conf.d/fault.cnf:/etc/mysql/conf.d/fault.cnf:ro" -v "$root/harness:/harness:ro" "$image" /harness/f2p.sh
docker run --rm --entrypoint /bin/bash -v "$work/etc/mysql/conf.d/fault.cnf:/etc/mysql/conf.d/fault.cnf:ro" -v "$root/harness:/harness:ro" "$image" /harness/p2p.sh
