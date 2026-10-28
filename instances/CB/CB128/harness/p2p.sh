#!/usr/bin/env bash
set -euo pipefail
test -d /srv/mysql/sockets
test -d /srv/mysql/myDB
id mysql >/dev/null
