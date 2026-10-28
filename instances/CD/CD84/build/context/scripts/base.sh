#!/usr/bin/env bash
set -euo pipefail
mkdir -p /var/lib/mysql
chown -R mysql:mysql /var/lib/mysql
if [ ! -d /var/lib/mysql/mysql ]; then
  mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql
fi
