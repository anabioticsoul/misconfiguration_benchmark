#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <prediction-patch> [image-name]"
  echo
  echo "Example:"
  echo "  $0 prediction.diff ca35:latest"
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="${2:-ca35:latest}"
ALLOWED_FILE="etc/mysql/my.cnf"
BASE_CONFIG="$CASE_DIR/workspace/$ALLOWED_FILE"

if [ ! -f "$1" ]; then
  echo "[FAIL] Prediction patch not found: $1"
  exit 1
fi

PATCH_FILE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

if [ ! -f "$BASE_CONFIG" ]; then
  echo "[FAIL] Baseline configuration not found: $BASE_CONFIG"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "[FAIL] git is required on the evaluator host."
  exit 1
fi

echo "[CA35] Checking prediction patch policy..."

set +e
CHANGED_FILES="$(git apply --numstat --unsafe-paths "$PATCH_FILE" 2>/dev/null | cut -f3- | sort -u)"
PATCH_PARSE_STATUS=$?
set -e

if [ "$PATCH_PARSE_STATUS" -ne 0 ] || [ -z "$CHANGED_FILES" ]; then
  echo "[FAIL] Patch is empty or is not a valid unified diff."
  exit 1
fi

if [ "$CHANGED_FILES" != "$ALLOWED_FILE" ]; then
  echo "[FAIL] Patch modifies files outside the allowed repair surface:"
  echo "$CHANGED_FILES" | sed 's#^#  /#'
  echo "[INFO] CA35 permits changes only to /$ALLOWED_FILE."
  exit 1
fi

if ! grep -qE '^[+-][[:space:]]*password[[:space:]]*=' "$PATCH_FILE"; then
  echo "[FAIL] Patch must modify the client password option."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "[FAIL] Docker daemon is unavailable."
  exit 1
fi

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "[FAIL] Docker image not found: $IMAGE_NAME"
  exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ca35-staging.XXXXXX")"
CONTAINER_NAME="ca35-eval-$$"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$STAGING_DIR/$(dirname "$ALLOWED_FILE")"
cp "$BASE_CONFIG" "$STAGING_DIR/$ALLOWED_FILE"

echo "[INFO] Applying prediction patch to an isolated copy of the allowed configuration..."

if ! (cd "$STAGING_DIR" && git apply --check --unsafe-paths "$PATCH_FILE"); then
  echo "[FAIL] Patch does not apply cleanly."
  exit 1
fi

(cd "$STAGING_DIR" && git apply --unsafe-paths "$PATCH_FILE")

echo "[INFO] Starting a fresh container with the patched configuration..."

docker create --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null
docker cp "$STAGING_DIR/$ALLOWED_FILE" "$CONTAINER_NAME:/$ALLOWED_FILE"
docker cp "$CASE_DIR/harness/eval.sh" "$CONTAINER_NAME:/tmp/ca35-eval.sh"
docker start "$CONTAINER_NAME" >/dev/null

for _ in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" bash -lc 'test -S /var/run/mysqld/mysqld.sock'; then
    break
  fi
  sleep 1
done

if ! docker exec "$CONTAINER_NAME" bash -lc 'test -S /var/run/mysqld/mysqld.sock'; then
  echo "[FAIL] MySQL did not become ready."
  docker logs "$CONTAINER_NAME"
  exit 1
fi

echo "[INFO] Running behavioral evaluation..."

docker exec "$CONTAINER_NAME" bash /tmp/ca35-eval.sh

echo "[PASS] Prediction patch passed CA35 evaluation."
