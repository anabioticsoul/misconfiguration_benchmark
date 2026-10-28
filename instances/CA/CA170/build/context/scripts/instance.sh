#!/usr/bin/env bash
set -euo pipefail
config=/var/lib/postgresql/data/postgresql.conf
sed -i "s/^lc_messages = 'C'$/lc_messages = 'ru_RU.UTF-8'/" "$config"
chown postgres:postgres "$config"
