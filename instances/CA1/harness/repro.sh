#!/usr/bin/env bash
set -euo pipefail
rm -f /tmp/ca1-mysqld.sock /tmp/ca1-mysqld.pid /tmp/ca1-repro.log
set +e
mysqld --user=mysql --datadir=/var/lib/mysql --socket=/tmp/ca1-mysqld.sock --pid-file=/tmp/ca1-mysqld.pid >/tmp/ca1-repro.log 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -F -- 'query_cache_size-128M' /tmp/ca1-repro.log
