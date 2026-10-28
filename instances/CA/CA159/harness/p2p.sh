#!/usr/bin/env bash
set -euo pipefail
apache2ctl -f /etc/apache2/ca159.conf -k start >/dev/null 2>&1 || true
for port in 8443 9443; do
  body="$(curl --insecure --fail --silent https://127.0.0.1:${port}/test.jsp)"
  if [ "$port" = 8443 ]; then expected='backend-one-ok'; else expected='backend-two-ok'; fi
  case "$body" in
    "$expected"*) ;;
    *) echo "unexpected backend body: $body" >&2; exit 1;;
  esac
done
config_body="$(cat /etc/apache2/loadbalancer.conf)"
case "$config_body" in
  *http://127.0.0.1*)
    echo 'backend proxy protocol changed to HTTP' >&2
    exit 1
    ;;
esac
case "$config_body" in
  *https://127.0.0.1*) ;;
  *) echo 'HTTPS backend members are missing' >&2; exit 1 ;;
esac
