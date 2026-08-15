#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <prediction-patch> [image-name]"
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="${2:-ca14:latest}"
ALLOWED_FILE="etc/mysql/my.cnf"
PATCH_FILE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ca14-staging.XXXXXX")"
CONTAINER_NAME="ca14-eval-$$"
BASELINE_CONTAINER="ca14-baseline-$$"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker rm -f "$BASELINE_CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

CHANGED_FILES="$(git apply --numstat --unsafe-paths "$PATCH_FILE" | cut -f3- | sort -u)"
if [ "$CHANGED_FILES" != "$ALLOWED_FILE" ]; then
  echo "[FAIL] Patch may modify only /$ALLOWED_FILE."
  exit 1
fi
if ! grep -qE '^[+-](default_)?time_zone=' "$PATCH_FILE"; then
  echo "[FAIL] Patch must repair the time-zone option."
  exit 1
fi

mkdir -p "$STAGING_DIR/$(dirname "$ALLOWED_FILE")"
docker create --name "$BASELINE_CONTAINER" "$IMAGE_NAME" >/dev/null
docker cp "$BASELINE_CONTAINER:/$ALLOWED_FILE" "$STAGING_DIR/$ALLOWED_FILE"
docker rm -f "$BASELINE_CONTAINER" >/dev/null

(cd "$STAGING_DIR" && git apply --check --unsafe-paths "$PATCH_FILE")
(cd "$STAGING_DIR" && git apply --unsafe-paths "$PATCH_FILE")

docker create --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null
docker cp "$STAGING_DIR/$ALLOWED_FILE" "$CONTAINER_NAME:/$ALLOWED_FILE"
docker cp "$CASE_DIR/harness/f2p.sh" "$CONTAINER_NAME:/tmp/ca14-f2p.sh"
docker cp "$CASE_DIR/harness/p2p.sh" "$CONTAINER_NAME:/tmp/ca14-p2p.sh"
docker start "$CONTAINER_NAME" >/dev/null

for _ in $(seq 1 60); do
  docker exec "$CONTAINER_NAME" test -S /var/run/mysqld/mysqld.sock 2>/dev/null \
    && break
  sleep 1
done
docker exec "$CONTAINER_NAME" test -S /var/run/mysqld/mysqld.sock
docker exec "$CONTAINER_NAME" bash /tmp/ca14-f2p.sh
docker exec "$CONTAINER_NAME" bash /tmp/ca14-p2p.sh
echo "[PASS] CA14 prediction passed evaluation."
