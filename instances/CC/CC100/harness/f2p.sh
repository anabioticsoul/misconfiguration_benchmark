#!/usr/bin/env bash
set -euo pipefail
cd /opt/cc100
mvn -q -DskipTests package
java -jar target/cc100-0.0.1-SNAPSHOT.jar >/tmp/cc100-f2p.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
response=000
for i in $(seq 1 60); do
  response=$(curl -sS -o /tmp/cc100-f2p-response -w '%{http_code}' http://127.0.0.1:8080/ 2>/dev/null || true)
  if [ "$response" != "000" ]; then
    break
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    cat /tmp/cc100-f2p.log >&2
    exit 1
  fi
  sleep 1
done
[ "$response" = "200" ]
grep -q '<h1>Hello</h1>' /tmp/cc100-f2p-response
