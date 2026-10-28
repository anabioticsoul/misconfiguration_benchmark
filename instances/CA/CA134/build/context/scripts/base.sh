#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends mariadb-server mariadb-client
rm -rf /var/lib/apt/lists/*
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
service mariadb start
for i in $(seq 1 30); do mysqladmin --protocol=socket ping >/dev/null 2>&1 && break; sleep 1; done
mysql --protocol=socket -uroot <<'SQL'
CREATE DATABASE IF NOT EXISTS ca134;
CREATE TABLE IF NOT EXISTS ca134.records (id INT PRIMARY KEY, event_date DATE NOT NULL);
INSERT INTO ca134.records VALUES (1, '2024-01-01') ON DUPLICATE KEY UPDATE id=id;
SQL
service mariadb stop
