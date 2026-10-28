#!/usr/bin/env bash
set -euo pipefail

mkdir -p /etc/mysql/conf.d /run/mysqld /opt/cd4
chown mysql:mysql /run/mysqld
chmod 0755 /usr/local/bin/cd4-entrypoint
ln -sf /usr/local/bin/cd4-entrypoint /usr/local/bin/runtime
: > /opt/cd4/dump.sql
for line in $(seq 1 149350); do
  printf '%s\n' '-- CD4 dump filler' >> /opt/cd4/dump.sql
done
printf '%s' "INSERT INTO cd4db.payload (data) VALUES ('" >> /opt/cd4/dump.sql
head -c 1200000 /dev/zero | tr '\0' 'x' >> /opt/cd4/dump.sql
printf '%s\n' "');" >> /opt/cd4/dump.sql
chown -R mysql:mysql /opt/cd4 /run/mysqld
chmod 0644 /opt/cd4/dump.sql
