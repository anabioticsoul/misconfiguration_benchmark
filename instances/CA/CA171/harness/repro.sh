#!/usr/bin/env bash
set -euo pipefail

socket=/tmp/ca171.sock
log=/tmp/ca171-repro-mysqld.log
rm -f "$socket" "$log"
mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking --socket="$socket" --pid-file=/tmp/ca171-repro.pid >"$log" 2>&1 &
pid=$!
cleanup() {
    status=$?
    mysqladmin --protocol=socket --socket="$socket" -uroot shutdown >/dev/null 2>&1 || true
    wait "$pid" || true
    if [ "$status" -ne 0 ]; then
        cat "$log" >&2
    fi
    rm -f "$socket" /tmp/ca171-repro.pid
    exit "$status"
}
trap cleanup EXIT

for _ in $(seq 1 60); do
    if mysqladmin --protocol=socket --socket="$socket" -uroot ping >/dev/null 2>&1; then
        break
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
        cat "$log"
        exit 1
    fi
    sleep 1
done
if ! mysqladmin --protocol=socket --socket="$socket" -uroot ping >/dev/null 2>&1; then
    cat "$log"
    exit 1
fi

if php /opt/ca171/reproduce.php > /tmp/ca171-repro-result.log 2> /tmp/ca171-repro-error.log; then
    cat /tmp/ca171-repro-result.log
    echo "expected the PDO update not to persist" >&2
    exit 1
fi
if ! grep -Fq "Update was not persisted" /tmp/ca171-repro-error.log; then
    cat /tmp/ca171-repro-error.log >&2
    exit 1
fi
cat /tmp/ca171-repro-error.log >&2
