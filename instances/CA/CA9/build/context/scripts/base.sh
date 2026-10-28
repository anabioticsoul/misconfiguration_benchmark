#!/usr/bin/env bash
set -euo pipefail
# The official image already provides PostgreSQL and its entrypoint.
test -x /usr/local/bin/docker-entrypoint.sh
test -f /usr/share/postgresql/postgresql.conf.sample
