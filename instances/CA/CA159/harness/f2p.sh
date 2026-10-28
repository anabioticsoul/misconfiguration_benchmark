#!/usr/bin/env bash
set -euo pipefail
apache2ctl -f /etc/apache2/ca159.conf -k start >/dev/null 2>&1 || true
for _ in $(seq 1 30); do
  if curl --fail --silent --show-error http://127.0.0.1:8080/test/test.jsp >/tmp/ca159-proxy.out 2>/tmp/ca159-curl.err; then
    if grep -Eq 'backend-(one|two)-ok' /tmp/ca159-proxy.out; then
      exit 0
    fi
  fi
  sleep 1
done
cat /tmp/ca159-curl.err >&2
exit 1
