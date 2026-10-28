#!/usr/bin/env bash
set -euo pipefail
chmod 0644 /etc/mysql/conf.d/cb116.cnf
if test ! -d /var/lib/mysql/mysql; then
  mysql_install_db --user=mysql --datadir=/var/lib/mysql >/dev/null
fi
chown -R mysql:mysql /var/lib/mysql
