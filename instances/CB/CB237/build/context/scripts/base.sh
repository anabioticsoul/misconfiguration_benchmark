#!/usr/bin/env bash
set -euo pipefail

install -d -o postgres -g postgres /opt/cb237/data /opt/cb237/logs
if [ ! -s /opt/cb237/data/PG_VERSION ]; then
  gosu postgres /usr/lib/postgresql/14/bin/initdb -D /opt/cb237/data --auth-local=peer --auth-host=scram-sha-256
  gosu postgres /usr/lib/postgresql/14/bin/pg_ctl -D /opt/cb237/data -o '-p 5432 -h 127.0.0.1' -w start -l /opt/cb237/logs/build-init.log
  cat >/tmp/cb237-init.sql <<'SQL'
CREATE ROLE my_username LOGIN PASSWORD 'my_password';
CREATE DATABASE raw_data OWNER my_username;
SQL
  gosu postgres /usr/lib/postgresql/14/bin/psql -p 5432 -d postgres -f /tmp/cb237-init.sql
  gosu postgres /usr/lib/postgresql/14/bin/pg_ctl -D /opt/cb237/data -m fast -w stop
  rm -f /tmp/cb237-init.sql /opt/cb237/logs/build-init.log
fi
