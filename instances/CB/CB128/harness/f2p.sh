#!/usr/bin/env bash
set -euo pipefail
profile=/etc/apparmor.d/usr.sbin.mysqld
grep -F '/srv/mysql/pids/mysqld-myDB.pid w,' "$profile" >/dev/null
grep -F '/srv/mysql/sockets/mysql-myDB.sock w,' "$profile" >/dev/null
chown mysql:mysql /srv/mysql/pids /srv/mysql/sockets
chmod 755 /srv/mysql/pids /srv/mysql/sockets
rm -f /srv/mysql/sockets/mysql-myDB.sock /srv/mysql/pids/mysqld-myDB.pid
mysqld --no-defaults --user=mysql --datadir=/srv/mysql/myDB --socket=/srv/mysql/sockets/mysql-myDB.sock --pid-file=/srv/mysql/pids/mysqld-myDB.pid --port=3700 --skip-networking >/tmp/cb128-mysqld.log 2>&1 &
pid=$!
cleanup() { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
trap cleanup EXIT
for _ in $(seq 1 30); do
  if [ -S /srv/mysql/sockets/mysql-myDB.sock ]; then exit 0; fi
  if ! kill -0 "$pid" 2>/dev/null; then cat /tmp/cb128-mysqld.log; exit 1; fi
  sleep 1
done
cat /tmp/cb128-mysqld.log
exit 1
