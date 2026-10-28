#!/usr/bin/env bash
set -euo pipefail
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || { echo 'usage: eval_patch.sh <prediction-patch> [image-name]' >&2; exit 2; }
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-ca134:latest}"
work="$(mktemp -d)"
fault_container="ca134-eval-fault-$$"
patched_container="ca134-eval-patched-$$"
cleanup() { docker rm -f "$fault_container" "$patched_container" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/etc/mysql/mariadb.conf.d"
docker run -d --name "$fault_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$fault_container:/etc/mysql/mariadb.conf.d/99-ca134.cnf" "$work/etc/mysql/mariadb.conf.d/99-ca134.cnf"
docker rm -f "$fault_container" >/dev/null
cd "$work"
git init -q
git config user.email evaluator@localhost
git config user.name evaluator
git add etc/mysql/mariadb.conf.d/99-ca134.cnf
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed=$(git diff --name-only HEAD)
[ "$changed" = 'etc/mysql/mariadb.conf.d/99-ca134.cnf' ]
docker run -d --name "$patched_container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$work/etc/mysql/mariadb.conf.d/99-ca134.cnf" "$patched_container:/etc/mysql/mariadb.conf.d/99-ca134.cnf"
docker exec "$patched_container" bash -lc 'service mariadb start >/dev/null; for i in $(seq 1 30); do mysqladmin --protocol=socket ping >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1'
docker exec -i "$patched_container" bash -s < "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/f2p.sh"
docker exec -i "$patched_container" bash -s < "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/p2p.sh"
