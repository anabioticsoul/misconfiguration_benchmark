#!/usr/bin/env bash
set -euo pipefail

CONFIG=/etc/mysql/my.cnf
FIXED_CONFIG=/tmp/ca14-fixed-my.cnf
cp "$CONFIG" "$FIXED_CONFIG"
sed -i '/^default_time_zone=/d' "$CONFIG"

mysqld --user=mysql --daemonize
for _ in $(seq 1 60); do
  test -S /var/run/mysqld/mysqld.sock && break
  sleep 1
done
test -S /var/run/mysqld/mysqld.sock

mysql_tzinfo_to_sql /usr/share/zoneinfo \
  | mysql --no-defaults -uroot '-pca35\spass' mysql
mysqladmin --no-defaults -uroot '-pca35\spass' shutdown
mv "$FIXED_CONFIG" "$CONFIG"
