#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
  printf 'usage: %s <prediction-patch> [image-name]\n' "$0" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cb263:latest}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/cb263-eval.XXXXXX")"
faulty=""
fixed=""
cleanup() {
  set +e
  if [[ -n "$faulty" ]]; then docker rm -f "$faulty" >/dev/null 2>&1; fi
  if [[ -n "$fixed" ]]; then docker rm -f "$fixed" >/dev/null 2>&1; fi
  rm -rf "$work_dir"
}
trap cleanup EXIT

faulty="cb263-faulty-$$"
fixed="cb263-fixed-$$"
staging="$work_dir/staging"
mkdir -p "$staging/opt/hadoop/etc/hadoop"

docker create --name "$faulty" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$faulty:/opt/hadoop/etc/hadoop/hdfs-site.xml" "$staging/opt/hadoop/etc/hadoop/hdfs-site.xml"
cd "$staging"
git init -q
git config user.name misconfigbench
git config user.email misconfigbench@example.invalid
git add opt/hadoop/etc/hadoop/hdfs-site.xml
git commit -qm baseline
git apply --check --unsafe-paths "$patch_file"
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
if [[ "$changed" != "opt/hadoop/etc/hadoop/hdfs-site.xml" ]]; then
  printf 'Prediction modified files outside the allowed configuration:\n%s\n' "$changed" >&2
  exit 1
fi
if ! git diff --quiet -- opt/hadoop/etc/hadoop/hdfs-site.xml; then
  :
else
  printf 'Prediction did not modify the allowed configuration\n' >&2
  exit 1
fi
patch_diff="$(git diff -- opt/hadoop/etc/hadoop/hdfs-site.xml)"
if [[ "$patch_diff" != *"dfs.datanode.du.reserved"* ]]; then
  printf 'Prediction did not modify dfs.datanode.du.reserved\n' >&2
  exit 1
fi

docker create --name "$fixed" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$staging/opt/hadoop/etc/hadoop/hdfs-site.xml" "$fixed:/opt/hadoop/etc/hadoop/hdfs-site.xml"
docker start "$fixed" >/dev/null
for attempt in $(seq 1 60); do
  if docker exec "$fixed" test -f /opt/hadoop/etc/hadoop/hdfs-site.xml; then
    break
  fi
  sleep 1
done
docker exec -i "$fixed" bash -s <"$script_dir/f2p.sh"
docker exec -i "$fixed" bash -s <"$script_dir/p2p.sh"
