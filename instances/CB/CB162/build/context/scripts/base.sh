#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  elixir \
  erlang-dev \
  erlang-ssl \
  git \
  openssl \
  postgresql \
  postgresql-client
rm -rf /var/lib/apt/lists/*

install -d -m 0755 /opt/cb162/config /opt/cb162/app/lib
chown -R root:root /opt/cb162

pg_version="14"
pg_conf="/etc/postgresql/${pg_version}/main/postgresql.conf"
pg_hba="/etc/postgresql/${pg_version}/main/pg_hba.conf"
install -d -o postgres -g postgres -m 0700 /var/lib/postgresql/${pg_version}/main
install -d -o postgres -g postgres -m 0700 /var/lib/postgresql/${pg_version}/main/ssl
openssl req -new -x509 -nodes -days 3650 -subj "/CN=cb162-postgres" \
  -out /var/lib/postgresql/${pg_version}/main/ssl/server.crt \
  -keyout /var/lib/postgresql/${pg_version}/main/ssl/server.key
chown postgres:postgres /var/lib/postgresql/${pg_version}/main/ssl/server.crt /var/lib/postgresql/${pg_version}/main/ssl/server.key
chmod 0600 /var/lib/postgresql/${pg_version}/main/ssl/server.key
cat >>"$pg_conf" <<'EOF'
ssl = on
ssl_cert_file = '/var/lib/postgresql/14/main/ssl/server.crt'
ssl_key_file = '/var/lib/postgresql/14/main/ssl/server.key'
ssl_min_protocol_version = 'TLSv1.2'
ssl_max_protocol_version = 'TLSv1.2'
listen_addresses = '127.0.0.1'
EOF
tmp_hba="$(mktemp)"
printf '%s\n' 'hostssl cb162 cb162 127.0.0.1/32 trust' >"$tmp_hba"
cat "$pg_hba" >>"$tmp_hba"
cat "$tmp_hba" >"$pg_hba"
rm -f "$tmp_hba"

pg_ctlcluster 14 main start
runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "CREATE USER cb162;" || true
runuser -u postgres -- createdb -O cb162 cb162 || true
pg_ctlcluster 14 main stop

cd /opt/cb162/app
export MIX_ENV=dev
mix local.hex --force
mix local.rebar --force
mix deps.get
mix compile
touch /opt/cb162/READY
