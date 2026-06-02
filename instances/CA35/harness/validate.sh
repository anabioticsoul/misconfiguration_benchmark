#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="ca35:latest"
IMAGE_ARCHIVE="$CASE_DIR/image/CA35.tar.gz"
CONTAINER_NAME="ca35-repro-$$"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[CA35] Validating benchmark case..."

required_files=(
  "$CASE_DIR/instance.json"
  "$CASE_DIR/testcase/description.md"
  "$CASE_DIR/testcase/metadata.json"
  "$CASE_DIR/testcase/gold_patch.diff"
  "$CASE_DIR/workspace/etc/mysql/my.cnf"
  "$CASE_DIR/harness/repro.sh"
  "$CASE_DIR/harness/eval.sh"
  "$CASE_DIR/eval/eval_patch.sh"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "[FAIL] Missing required file: $file"
    exit 1
  fi
done

echo "[INFO] Checking Docker image..."

if ! docker info >/dev/null 2>&1; then
  echo "[FAIL] Docker daemon is unavailable."
  exit 1
fi

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  if [ ! -f "$IMAGE_ARCHIVE" ]; then
    echo "[FAIL] Docker image not found: $IMAGE_NAME"
    echo "[FAIL] Root filesystem archive also not found: $IMAGE_ARCHIVE"
    exit 1
  fi

  echo "[INFO] Importing root filesystem archive: $IMAGE_ARCHIVE"
  docker import \
    --change 'ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]' \
    --change 'CMD ["mysqld"]' \
    "$IMAGE_ARCHIVE" \
    "$IMAGE_NAME" >/dev/null
fi

echo "[INFO] Running reproduction script in a fresh container..."

docker create --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null
docker cp "$CASE_DIR/harness/repro.sh" "$CONTAINER_NAME:/tmp/ca35-repro.sh"
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

docker exec "$CONTAINER_NAME" bash /tmp/ca35-repro.sh
docker rm -f "$CONTAINER_NAME" >/dev/null

echo "[INFO] Applying gold patch and running policy-aware evaluation..."

"$CASE_DIR/eval/eval_patch.sh" "$CASE_DIR/testcase/gold_patch.diff" "$IMAGE_NAME"

echo "[PASS] CA35 validation succeeded."
