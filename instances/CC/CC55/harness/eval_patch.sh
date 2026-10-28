#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  printf 'usage: %s <prediction-patch> [image-name]\n' "$0" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cc55:latest}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
workdir="$(mktemp -d)"
source_name="cc55-eval-source-$$"
repaired_name="cc55-eval-repaired-$$"
source_log="$workdir/source.log"
repaired_log="$workdir/repaired.log"
cleanup() {
  docker rm -f "$source_name" "$repaired_name" >/dev/null 2>&1 || true
  rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$workdir/opt/intellij-fixture/project/.idea/modules"
docker run -d --name "$source_name" "$image" bash -lc 'exec tail -f /dev/null' >"$source_log"
for _ in $(seq 1 60); do
  if docker exec "$source_name" test -x /usr/local/bin/intellij-spring-check && \
     docker exec "$source_name" test -f /opt/intellij-fixture/project/.idea/modules/app.iml; then
    break
  fi
  sleep 1
done
if ! docker exec "$source_name" test -f /opt/intellij-fixture/project/.idea/modules/app.iml; then
  cat "$source_log" >&2
  printf '%s\n' 'Faulty container did not become ready.' >&2
  exit 1
fi
docker cp "$source_name:/opt/intellij-fixture/project/.idea/modules/app.iml" \
  "$workdir/opt/intellij-fixture/project/.idea/modules/app.iml"

cd "$workdir"
git init -q
git config user.name 'MisconfigBench evaluator'
git config user.email 'evaluator@misconfigbench.invalid'
git add opt/intellij-fixture/project/.idea/modules/app.iml
git commit -q -m baseline
if ! git apply --check --unsafe-paths "$patch_file"; then
  printf '%s\n' 'Prediction patch does not apply to the fresh faulty configuration.' >&2
  exit 1
fi
git apply --unsafe-paths "$patch_file"
modified="$(git diff --name-only)"
if [ "$modified" != 'opt/intellij-fixture/project/.idea/modules/app.iml' ]; then
  printf '%s\n' 'Prediction modified files outside the allowed module configuration.' >&2
  printf '%s\n' "$modified" >&2
  exit 1
fi

docker run -d --name "$repaired_name" "$image" bash -lc 'exec tail -f /dev/null' >"$repaired_log"
docker cp "$workdir/opt/intellij-fixture/project/.idea/modules/app.iml" \
  "$repaired_name:/opt/intellij-fixture/project/.idea/modules/app.iml"
for _ in $(seq 1 60); do
  if docker exec "$repaired_name" test -x /usr/local/bin/intellij-spring-check; then
    break
  fi
  sleep 1
done
if ! docker exec "$repaired_name" test -x /usr/local/bin/intellij-spring-check; then
  cat "$repaired_log" >&2
  printf '%s\n' 'Repaired container did not become ready.' >&2
  exit 1
fi

docker exec "$repaired_name" bash -s <"$script_dir/f2p.sh"
docker exec "$repaired_name" bash -s <"$script_dir/p2p.sh"
