#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
harness_dir="$(cd "$(dirname "$0")" && pwd)"
image="${2:-ca19:latest}"
root="$(mktemp -d)"
faulty_container="ca19-eval-faulty-$$"
repaired_container="ca19-eval-repaired-$$"
cleanup() {
  docker rm -f "$faulty_container" "$repaired_container" >/dev/null 2>&1 || true
  rm -rf "$root"
}
trap cleanup EXIT
mkdir -p "$root/opt/ca19"
docker create --name "$faulty_container" "$image" /bin/bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$faulty_container:/opt/ca19/SurveyClient.exe.config" "$root/opt/ca19/SurveyClient.exe.config"
cp "$patch_file" "$root/prediction.patch"
cd "$root"
git init -q
git config user.email evaluator@example.invalid
git config user.name evaluator
git add opt/ca19/SurveyClient.exe.config
git commit -qm baseline
git apply --unsafe-paths --check prediction.patch
git apply --unsafe-paths prediction.patch
changed="$(git diff --name-only)"
test "$changed" = "opt/ca19/SurveyClient.exe.config"
docker create --name "$repaired_container" "$image" /bin/bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$root/opt/ca19/SurveyClient.exe.config" "$repaired_container:/opt/ca19/SurveyClient.exe.config"
docker start "$repaired_container" >/dev/null
docker exec "$repaired_container" bash -lc 'test -x /opt/ca19/SurveyClient.exe'
docker cp "$harness_dir/f2p.sh" "$repaired_container:/tmp/ca19-f2p.sh"
docker cp "$harness_dir/p2p.sh" "$repaired_container:/tmp/ca19-p2p.sh"
docker exec "$repaired_container" bash -lc 'bash /tmp/ca19-f2p.sh'
docker exec "$repaired_container" bash -lc 'bash /tmp/ca19-p2p.sh'
