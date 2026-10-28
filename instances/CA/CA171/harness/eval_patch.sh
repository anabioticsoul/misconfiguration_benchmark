#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: eval_patch.sh <prediction-patch> [image-name]" >&2
    exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca171:latest}"
script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
stage="$(mktemp -d "${TMPDIR:-/tmp}/ca171-eval.XXXXXX")"
faulty_cid=""
patched_cid=""
cleanup() {
    if [ -n "$faulty_cid" ]; then docker rm -f "$faulty_cid" >/dev/null 2>&1 || true; fi
    if [ -n "$patched_cid" ]; then docker rm -f "$patched_cid" >/dev/null 2>&1 || true; fi
    rm -rf "$stage"
}
trap cleanup EXIT

mkdir -p "$stage/etc/mysql/conf.d"
faulty_cid="$(docker create "$image")"
docker cp "$faulty_cid:/etc/mysql/conf.d/ca171.cnf" "$stage/etc/mysql/conf.d/ca171.cnf"
docker rm "$faulty_cid" >/dev/null
faulty_cid=""

git -C "$stage" init -q
git -C "$stage" config user.name "openhands"
git -C "$stage" config user.email "openhands@all-hands.dev"
git -C "$stage" add etc/mysql/conf.d/ca171.cnf
git -C "$stage" commit -q -m baseline

git -C "$stage" apply --unsafe-paths "$patch_file"
changed="$( { git -C "$stage" diff --name-only; git -C "$stage" ls-files --others --exclude-standard; } | sort -u )"
if [ "$changed" != "etc/mysql/conf.d/ca171.cnf" ]; then
    echo "patch changed files outside the allowed configuration target:" >&2
    printf '%s\n' "$changed" >&2
    exit 1
fi

git -C "$stage" diff --quiet -- etc/mysql/conf.d/ca171.cnf && {
    echo "patch did not modify autocommit configuration" >&2
    exit 1
}
if ! grep -Fqx 'autocommit=1' "$stage/etc/mysql/conf.d/ca171.cnf"; then
    echo "patch did not set mysqld autocommit to 1" >&2
    exit 1
fi

patched_cid="$(docker create --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null')"
docker start "$patched_cid" >/dev/null
for _ in $(seq 1 60); do
    if docker exec "$patched_cid" test -f /etc/mysql/conf.d/ca171.cnf; then
        break
    fi
    sleep 1
done
docker exec "$patched_cid" test -f /etc/mysql/conf.d/ca171.cnf
docker cp "$stage/etc/mysql/conf.d/ca171.cnf" "$patched_cid:/etc/mysql/conf.d/ca171.cnf"
docker cp "$script_dir/f2p.sh" "$patched_cid:/tmp/ca171-f2p.sh"
docker cp "$script_dir/p2p.sh" "$patched_cid:/tmp/ca171-p2p.sh"

if ! docker exec "$patched_cid" /bin/bash /tmp/ca171-f2p.sh >"$stage/f2p.log" 2>&1; then
    cat "$stage/f2p.log" >&2
    exit 1
fi
if ! docker exec "$patched_cid" /bin/bash /tmp/ca171-p2p.sh >"$stage/p2p.log" 2>&1; then
    cat "$stage/p2p.log" >&2
    exit 1
fi
cat "$stage/f2p.log"
cat "$stage/p2p.log"
