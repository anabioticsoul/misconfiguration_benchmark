#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s <prediction-patch> [image-name]\n' "$0" >&2
    exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca142:latest}"
eval_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/ca142-eval.XXXXXX")"
extract_name="ca142-extract-$$"
container_name="ca142-eval-$$"
cleanup() {
    docker rm -f "$extract_name" "$container_name" >/dev/null 2>&1 || true
    rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$workdir/etc/flink"
docker create --name "$extract_name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$extract_name:/etc/flink/flink-conf.yaml" "$workdir/etc/flink/flink-conf.yaml"

cd "$workdir"
git init -q
git config user.name openhands
git config user.email openhands@all-hands.dev
git add etc/flink/flink-conf.yaml
git commit -q -m baseline
# Keep evaluator identity explicit even if the Git implementation requires it again.
git config user.name openhands
git config user.email openhands@all-hands.dev
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
if [ "$changed" != 'etc/flink/flink-conf.yaml' ]; then
    printf 'prediction modified files outside the allowed configuration: %s\n' "$changed" >&2
    exit 1
fi

docker create --name "$container_name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$workdir/etc/flink/flink-conf.yaml" "$container_name:/etc/flink/flink-conf.yaml"
docker start "$container_name" >/dev/null
ready=0
attempt=0
while [ "$attempt" -lt 60 ]; do
    if docker exec "$container_name" test -x /opt/flink/bin/checkpoint-probe && docker exec "$container_name" test -f /etc/flink/flink-conf.yaml; then
        ready=1
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    printf '%s\n' 'evaluation container did not become ready' >&2
    docker logs "$container_name" >&2 || true
    exit 1
fi

docker exec -i "$container_name" bash -s < "$eval_dir/f2p.sh"
docker exec -i "$container_name" bash -s < "$eval_dir/p2p.sh"
