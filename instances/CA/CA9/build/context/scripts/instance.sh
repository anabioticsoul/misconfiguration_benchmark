#!/usr/bin/env bash
set -euo pipefail

data=/var/lib/postgresql/data
mkdir -p "$data"
chown -R postgres:postgres /var/lib/postgresql
if test ! -f "$data/PG_VERSION"; then
  runuser -u postgres -- /usr/lib/postgresql/14/bin/initdb \
    --auth-local=trust --auth-host=trust -D "$data"
fi

config="$data/postgresql.conf"
test -f "$config"
sed -i -e "s/^[[:space:]]*#[[:space:]]*listen_addresses[[:space:]]*=.*/listen_addresses = ''         # what IP address(es) to listen on;/" \
       -e "s/^[[:space:]]*listen_addresses[[:space:]]*=.*/listen_addresses = ''         # what IP address(es) to listen on;/" "$config"
grep -Fq "listen_addresses = ''" "$config"
chown postgres:postgres "$config"
