#!/usr/bin/env bash
set -euo pipefail
patch_file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
image="${2:-cc70:latest}"
eval_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
root="$(mktemp -d)"
container="cc70-eval-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$root"; }
trap cleanup EXIT
mkdir -p "$root/opt/app"
docker create --name "$container" "$image" >/dev/null
docker cp "$container:/opt/app/pom.xml" "$root/opt/app/pom.xml"
docker rm "$container" >/dev/null
cd "$root"
git init -q
git config user.email evaluator@misconfigbench.invalid
git config user.name evaluator
git add opt/app/pom.xml
git commit -qm baseline
git apply --unsafe-paths "$patch_file"
changed="$(git diff --name-only HEAD)"
[ "$changed" = "opt/app/pom.xml" ] || { echo "patch modified unauthorized files: $changed" >&2; exit 1; }
docker run -d --name "$container" -p 127.0.0.1::8080 "$image" bash -lc 'exec tail -f /dev/null' >/dev/null
docker cp "$root/opt/app/pom.xml" "$container:/opt/app/pom.xml"
docker exec "$container" bash -lc 'cd /opt/app && mvn -q clean -DskipTests package' >/tmp/cc70-maven.log 2>&1 || { cat /tmp/cc70-maven.log >&2; exit 1; }
docker exec -d "$container" bash -lc 'exec java -jar /opt/app/target/login-register-0.0.1-SNAPSHOT.jar >/tmp/cc70-spring.log 2>&1' >/dev/null
ready=0
for _ in $(seq 1 60); do
  code="$(docker exec "$container" bash -lc "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/vs1/users" 2>/dev/null || true)"
  if [ "$code" = "200" ] || [ "$code" = "401" ]; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  docker exec "$container" bash -lc 'cat /tmp/cc70-spring.log' >&2 || true
  exit 1
fi
port="$(docker port "$container" 8080/tcp | sed 's/.*://')"
BASE_URL="http://127.0.0.1:$port" "$eval_dir/f2p.sh"
BASE_URL="http://127.0.0.1:$port" "$eval_dir/p2p.sh"
