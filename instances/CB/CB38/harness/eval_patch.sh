#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: $0 <prediction-patch> [image-name]" >&2
    exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb38:latest}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/cb38-eval.XXXXXX")"
faulty_container="cb38-extract-$$"
eval_container="cb38-eval-$$"
cleanup() {
    docker rm -f "$faulty_container" "$eval_container" >/dev/null 2>&1 || true
    rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$workdir/etc/nginx"
docker create --name "$faulty_container" "$image" >/dev/null
docker cp "$faulty_container:/etc/nginx/nginx.conf" "$workdir/etc/nginx/nginx.conf"
docker rm "$faulty_container" >/dev/null
faulty_container="cb38-extract-unused-$$"

cd "$workdir"
git init -q
git config user.name "openhands"
git config user.email "openhands@all-hands.dev"
git add etc/nginx/nginx.conf
git commit -q -m baseline
if ! git apply --unsafe-paths "$patch_file"; then
    echo "Prediction patch does not apply to the extracted configuration" >&2
    exit 1
fi
changed=$(git diff --name-only)
if [ "$changed" != "etc/nginx/nginx.conf" ]; then
    echo "Prediction modifies files outside /etc/nginx/nginx.conf" >&2
    printf '%s\n' "$changed" >&2
    exit 1
fi
diff_output=$(git diff -- etc/nginx/nginx.conf)
case "$diff_output" in
    *"user root;"*) ;;
    *)
        echo "Prediction does not repair the Nginx user directive" >&2
        exit 1
        ;;
esac

# Keep the fresh container alive while the allowed configuration is delivered.
docker run -d --name "$eval_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$workdir/etc/nginx/nginx.conf" "$eval_container:/etc/nginx/nginx.conf"
docker exec "$eval_container" nginx -g 'daemon off;' >"$workdir/nginx-start.log" 2>&1 &
nginx_pid=$!

ready=0
for _ in $(seq 1 30); do
    if response=$(docker exec "$eval_container" curl -sS --max-time 2 http://127.0.0.1/health 2>/dev/null); then
        if [ "$response" = "healthy" ]; then
            ready=1
            break
        fi
    fi
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    echo "Patched Nginx container did not become ready" >&2
    if [ -f "$workdir/nginx-start.log" ]; then
        cat "$workdir/nginx-start.log" >&2
    fi
    docker exec "$eval_container" cat /home/ubuntu/virtualenv/myapp/error/error.log >&2 || true
    exit 1
fi

docker exec "$eval_container" bash -s < "$script_dir/f2p.sh"
docker exec "$eval_container" bash -s < "$script_dir/p2p.sh"
