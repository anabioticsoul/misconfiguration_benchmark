#!/usr/bin/env bash
set -euo pipefail
service mariadb start >/dev/null
cleanup() { service mariadb stop >/dev/null 2>&1 || true; }
trap cleanup EXIT
for i in $(seq 1 30); do mysqladmin --protocol=socket ping >/dev/null 2>&1 && break; sleep 1; done
mysql --protocol=socket -uroot ca134 -N -e "SELECT COUNT(*) FROM records WHERE id=1" | grep -Fx '1' >/dev/null
