#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cc69:latest}"
self_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/stage/opt/cc69"
docker run --rm "$image" cat /opt/cc69/pom.xml > "$root/stage/opt/cc69/pom.xml"
cd "$root/stage"
git init -q
git config user.email evaluator@misconfigbench.local
git config user.name evaluator
git add .
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed=$(git diff --name-only)
[ "$changed" = "opt/cc69/pom.xml" ]
diff_text=$(git diff -- opt/cc69/pom.xml)
while IFS= read -r line; do
  case "$line" in
    diff\ --git*|index\ *|---*|+++*|@@*|" "*) ;;
    +*javax.transaction-api*) ;;
    *) echo 'patch changes forbidden content' >&2; exit 1 ;;
  esac
done <<EOF
$diff_text
EOF
container="cc69-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
# The standard image command keeps the evaluator container alive.
docker run -d --name "$container" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do docker exec "$container" test -f /opt/cc69/pom.xml && break; sleep 1; done
docker cp "$root/stage/opt/cc69/pom.xml" "$container:/opt/cc69/pom.xml"
docker exec -i "$container" bash -s < "$self_dir/f2p.sh"
docker exec -i "$container" bash -s < "$self_dir/p2p.sh"
