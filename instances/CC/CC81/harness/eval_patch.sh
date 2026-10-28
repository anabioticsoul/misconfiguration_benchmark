#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then echo "usage: $0 patch [image]" >&2; exit 2; fi
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cc81:latest}"
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
cleanup() { docker rm -f cc81-eval-$$ >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap cleanup EXIT
mkdir -p "$tmp/etc/springboot"
docker run --rm --entrypoint /bin/bash "$image" -lc 'cat /etc/springboot/java.options' > "$tmp/etc/springboot/java.options"
git -C "$tmp" init -q
git -C "$tmp" config user.email openhands@all-hands.dev
git -C "$tmp" config user.name openhands
git -C "$tmp" add etc/springboot/java.options
git -C "$tmp" commit -qm baseline
git -C "$tmp" apply --unsafe-paths "$patch_file"
test "$(git -C "$tmp" diff --name-only HEAD)" = "etc/springboot/java.options"
name="cc81-eval-$$"
docker run -d --name "$name" --entrypoint /bin/bash "$image" -lc 'exec tail -f /dev/null' >/dev/null
for _ in $(seq 1 30); do docker exec "$name" test -f /etc/springboot/java.options && break; sleep 1; done
cat "$tmp/etc/springboot/java.options" | docker exec -i "$name" tee /etc/springboot/java.options >/dev/null
docker exec -i "$name" bash -s < "$root/harness/f2p.sh"
docker exec -i "$name" bash -s < "$root/harness/p2p.sh"
