#!/usr/bin/env bash
set -euo pipefail
test -x /usr/sbin/mysqld
test -f /etc/mysql/conf.d/fault.cnf
grep -F '[mysqld]' /etc/mysql/conf.d/fault.cnf >/dev/null
! grep -E -- '--no-defaults|skip-grant-tables' /etc/mysql/conf.d/fault.cnf >/dev/null
