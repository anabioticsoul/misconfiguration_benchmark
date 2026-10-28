#!/usr/bin/env bash
set -euo pipefail

control_log=/tmp/ca129-f2p-control.log
apache_log=/var/log/apache2/error.log
handshake=/tmp/ca129-f2p-handshake.log
: > "$control_log"
: > "$apache_log"
: > "$handshake"
apache2ctl -DFOREGROUND >"$control_log" 2>&1 &
apache_pid=$!

ready=0
for _ in $(seq 1 60); do
  if ! kill -0 "$apache_pid" 2>/dev/null; then
    cat "$control_log" "$apache_log" "$handshake" >&2
    echo "Apache exited while starting" >&2
    exit 1
  fi
  if openssl s_client -connect 127.0.0.1:443 -servername my-domain.com \
      -CAfile /etc/apache2/ssl.crt/minecraft-multiplayer_com.ca-bundle \
      -brief </dev/null >"$handshake" 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  cat "$control_log" "$apache_log" "$handshake" >&2
  echo "Apache did not become ready for an HTTPS handshake" >&2
  exit 1
fi
cat "$control_log"
