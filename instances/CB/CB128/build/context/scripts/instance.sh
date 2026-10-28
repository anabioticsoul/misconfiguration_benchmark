#!/usr/bin/env bash
set -euo pipefail
chmod 644 /etc/apparmor.d/usr.sbin.mysqld /etc/mysql/conf.d/cb128.cnf
# Docker Desktop does not expose the host AppArmor LSM to containers. Model the
# denied custom-path capability with the same mysql-owned socket and PID paths.
chown root:root /srv/mysql/pids /srv/mysql/sockets
chmod 700 /srv/mysql/pids /srv/mysql/sockets
