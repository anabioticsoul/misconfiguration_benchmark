#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends locales ca-certificates
sed -i '/^# *ru_RU.UTF-8 UTF-8/s/^# *//' /etc/locale.gen
sed -i '/^# *en_US.UTF-8 UTF-8/s/^# *//' /etc/locale.gen
locale-gen
rm -rf /var/lib/postgresql/data
install -d -o postgres -g postgres -m 700 /var/lib/postgresql/data
runuser -u postgres -- initdb -D /var/lib/postgresql/data --locale=C.UTF-8 --encoding=UTF8 >/dev/null
config=/var/lib/postgresql/data/postgresql.conf
sed -i -E "s|^lc_messages = .*|lc_messages = 'C'|" "$config"
printf 'host all all 127.0.0.1/32 trust\n' >> /var/lib/postgresql/data/pg_hba.conf
chown postgres:postgres /var/lib/postgresql/data/postgresql.conf /var/lib/postgresql/data/pg_hba.conf
rm -rf /var/lib/apt/lists/*
