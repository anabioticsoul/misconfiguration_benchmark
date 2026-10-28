#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <prediction-patch> [image-name]" >&2
  exit 2
fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca129:latest}"
self_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
root="$(mktemp -d "${TMPDIR:-/tmp}/ca129-eval.XXXXXX")"
fault_name="ca129-fault-$$"
fixed_name="ca129-fixed-$$"
cleanup() {
  docker rm -f "$fault_name" "$fixed_name" >/dev/null 2>&1 || true
  rm -rf "$root"
}
trap cleanup EXIT

mkdir -p "$root/etc/apache2/sites-available"
docker run -d --name "$fault_name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$fault_name:/etc/apache2/sites-available/ca129-ssl.conf" \
  "$root/etc/apache2/sites-available/ca129-ssl.conf"

cd "$root"
git init -q
git config user.name misconfigbench-evaluator
git config user.email evaluator@misconfigbench.invalid
git add etc/apache2/sites-available/ca129-ssl.conf
git commit -q -m baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only)"
if [ "$changed" != "etc/apache2/sites-available/ca129-ssl.conf" ]; then
  echo "prediction modifies disallowed files: $changed" >&2
  exit 1
fi

docker run -d --name "$fixed_name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$root/etc/apache2/sites-available/ca129-ssl.conf" \
  "$fixed_name:/etc/apache2/sites-available/ca129-ssl.conf"
for _ in $(seq 1 60); do
  if docker exec "$fixed_name" test -f /etc/apache2/sites-available/ca129-ssl.conf; then
    break
  fi
  sleep 1
done
docker exec "$fixed_name" test -f /etc/apache2/sites-available/ca129-ssl.conf

docker exec "$fixed_name" /bin/bash -s < "$self_dir/f2p.sh"
docker exec "$fixed_name" /bin/bash -s < "$self_dir/p2p.sh"
