#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends mysql-server php-cli php-mysql
rm -rf /var/lib/apt/lists/*

service mysql stop >/dev/null 2>&1 || true
install -d -o mysql -g mysql /var/run/mysqld
install -d /etc/mysql/conf.d
if [ ! -f /etc/mysql/my.cnf ]; then
    printf '%s\n' '[mysqld]' > /etc/mysql/my.cnf
fi
if ! grep -Fq '!includedir /etc/mysql/conf.d' /etc/mysql/my.cnf; then
    printf '\n%s\n' '!includedir /etc/mysql/conf.d' >> /etc/mysql/my.cnf
fi
if [ ! -d /var/lib/mysql/mysql ]; then
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql
fi

socket=/tmp/ca171-build.sock
log=/tmp/ca171-build-mysqld.log
rm -f "$socket" "$log" /tmp/ca171-build.pid
mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking --socket="$socket" --pid-file=/tmp/ca171-build.pid >"$log" 2>&1 &
pid=$!
cleanup() {
    mysqladmin --protocol=socket --socket="$socket" -uroot shutdown >/dev/null 2>&1 || true
    wait "$pid" || true
    rm -f "$socket" /tmp/ca171-build.pid "$log"
}
trap cleanup EXIT

ready=0
for _ in $(seq 1 60); do
    if mysqladmin --protocol=socket --socket="$socket" -uroot ping >/dev/null 2>&1; then
        ready=1
        break
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
        cat "$log"
        exit 1
    fi
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    cat "$log"
    exit 1
fi

mysql --protocol=socket --socket="$socket" -uroot <<'SQL'
CREATE DATABASE IF NOT EXISTS ca171;
USE ca171;
CREATE TABLE IF NOT EXISTS teams (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);
DELETE FROM teams;
INSERT INTO teams (id, name) VALUES (1, 'Original');
COMMIT;
SQL
