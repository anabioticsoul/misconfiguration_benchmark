#!/usr/bin/env bash
set -euo pipefail
export SPARK_LOCAL_IP=127.0.0.1
export SPARK_HOME=/opt/spark
export PYTHONPATH="$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip${PYTHONPATH:+:$PYTHONPATH}"
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca163:latest}"
root="$(mktemp -d)"
container="ca163-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/opt/ca163"
docker create --name "$container" "$image" >/dev/null
docker cp "$container:/opt/ca163/query.conf" "$root/opt/ca163/query.conf"
cd "$root"
git init -q
git config user.email evaluator@example.invalid
git config user.name evaluator
git add opt/ca163/query.conf
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only HEAD)"
[ "$changed" = "opt/ca163/query.conf" ]
grep -F '[streaming]' opt/ca163/query.conf >/dev/null
if grep -F 'checkpointLocation' opt/ca163/query.conf >/dev/null; then
  exit 1
fi
docker rm -f "$container" >/dev/null
docker run -d --name "$container" "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$root/opt/ca163/query.conf" "$container:/opt/ca163/query.conf"
docker exec -e SPARK_LOCAL_IP=127.0.0.1 -e SPARK_HOME=/opt/spark -e PYTHONPATH=/opt/spark/python:/opt/spark/python/lib/py4j-0.10.9.7-src.zip "$container" bash -lc 'rm -rf /tmp/ca163-checkpoint; python3 /opt/ca163/socket_checkpoint.py --smoke'
