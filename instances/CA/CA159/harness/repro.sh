#!/usr/bin/env bash
set -euo pipefail
apache2ctl -f /etc/apache2/ca159.conf -k start
for _ in $(seq 1 30); do
  if curl --fail --silent --show-error --output /dev/null http://127.0.0.1:8080/test/test.jsp 2>/tmp/ca159-curl.err; then
    echo 'unexpected successful proxied request' >&2
    exit 1
  fi
  if grep -Eq 'returned error: (500|502)' /tmp/ca159-curl.err; then
    exit 0
  fi
  sleep 1
done
cat /tmp/ca159-curl.err >&2
exit 1
