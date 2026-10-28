#!/usr/bin/env bash
set -euo pipefail
mkdir -p /srv/mysql/{myDB,logs,pids,sockets}
chown -R mysql:mysql /srv/mysql
if [ ! -d /srv/mysql/myDB/mysql ]; then
  mysqld --initialize-insecure --user=mysql --datadir=/srv/mysql/myDB >/tmp/cb128-init.log 2>&1
fi
chmod 755 /srv/mysql /srv/mysql/myDB /srv/mysql/logs /srv/mysql/pids /srv/mysql/sockets
