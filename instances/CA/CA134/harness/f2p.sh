#!/usr/bin/env bash
set -euo pipefail
service mariadb start >/dev/null
cleanup() { service mariadb stop >/dev/null 2>&1 || true; }
trap cleanup EXIT
for i in $(seq 1 30); do mysqladmin --protocol=socket ping >/dev/null 2>&1 && break; sleep 1; done
mysql --protocol=socket -uroot ca134 -e "INSERT INTO records (id, event_date) VALUES (2, '0000-00-00')"
mysql --protocol=socket -uroot ca134 -N -e "SELECT event_date FROM records WHERE id=2" | grep -F '0000-00-00' >/dev/null
