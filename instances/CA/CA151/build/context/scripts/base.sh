#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends mysql-server mysql-client iproute2 ca-certificates
rm -rf /var/lib/apt/lists/*
# Ubuntu's package default is loopback-only; make the clean base TCP-reachable.
if [ -f /etc/mysql/mysql.conf.d/mysqld.cnf ]; then
  sed -i 's/^bind-address[[:space:]]*=.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
fi
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
