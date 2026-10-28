#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: $0 <prediction-patch> [image-name]" >&2
    exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb83:latest}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
workdir=$(mktemp -d "${TMPDIR:-/tmp}/cb83-eval.XXXXXX")
source_container="cb83-source-$$"
fixed_container="cb83-fixed-$$"

cleanup() {
    docker rm -f "$source_container" "$fixed_container" >/dev/null 2>&1 || true
    rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$workdir/etc/apache2/conf-enabled"
docker create --name "$source_container" "$image" >/dev/null
docker cp "$source_container:/etc/apache2/conf-enabled/legacy-listen.conf" "$workdir/etc/apache2/conf-enabled/legacy-listen.conf"

cd "$workdir"
git init -q
git config user.name "openhands"
git config user.email "openhands@all-hands.dev"
git add -A
git commit -q -m baseline
if ! git apply --unsafe-paths "$patch_file"; then
    echo 'Prediction patch did not apply.' >&2
    exit 1
fi
changed=$(git diff --name-only)
if [ "$changed" != "etc/apache2/conf-enabled/legacy-listen.conf" ]; then
    echo 'Prediction patch modified files outside the allowed configuration path.' >&2
    printf 'Changed files:\n%s\n' "$changed" >&2
    exit 1
fi

# The repaired configuration is delivered into a fresh container without copying harnesses.
docker create --name "$fixed_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker start "$fixed_container" >/dev/null
patched_file="$workdir/etc/apache2/conf-enabled/legacy-listen.conf"
if [ -e "$patched_file" ]; then
    docker cp "$patched_file" "$fixed_container:/etc/apache2/conf-enabled/legacy-listen.conf"
else
    docker exec "$fixed_container" rm -f /etc/apache2/conf-enabled/legacy-listen.conf
fi

f2p_status=0
p2p_status=0
docker exec -i "$fixed_container" /bin/bash -s < "$script_dir/f2p.sh" || f2p_status=$?
docker exec -i "$fixed_container" /bin/bash -s < "$script_dir/p2p.sh" || p2p_status=$?
if [ "$f2p_status" -ne 0 ] || [ "$p2p_status" -ne 0 ]; then
    echo "Evaluation failed: f2p=$f2p_status p2p=$p2p_status" >&2
    exit 1
fi
