#!/usr/bin/env bash
set -euo pipefail

fpm_log=/tmp/cd253-repro-fpm.log
apache_log=/tmp/cd253-repro-apache.log
body_file=/tmp/cd253-repro-body
fpm_pid=
apache_pid=

cleanup() {
    if [ -n "${apache_pid}" ]; then
        kill "${apache_pid}" 2>/dev/null || true
        wait "${apache_pid}" 2>/dev/null || true
    fi
    if [ -n "${fpm_pid}" ]; then
        kill "${fpm_pid}" 2>/dev/null || true
        wait "${fpm_pid}" 2>/dev/null || true
    fi
}

report_failure() {
    printf '%s\n' '--- PHP-FPM startup log ---'
    cat "$fpm_log" 2>/dev/null || true
    printf '%s\n' '--- Apache startup log ---'
    cat "$apache_log" 2>/dev/null || true
    printf '%s\n' '--- Apache error log ---'
    cat /var/log/apache2/error.log 2>/dev/null || true
}

on_exit() {
    rc=$?
    if [ "$rc" -ne 0 ]; then
        report_failure
    fi
    cleanup
    exit "$rc"
}
trap on_exit EXIT

: > "$fpm_log"
: > "$apache_log"
: > /var/log/apache2/error.log
rm -f /run/php/php7.4-fpm.sock "$body_file"

/usr/local/php7.4/sbin/php-fpm -F -y /etc/php/7.4/fpm/php-fpm.conf >"$fpm_log" 2>&1 &
fpm_pid=$!
fpm_ready=0
for _ in $(seq 1 30); do
    if [ -S /run/php/php7.4-fpm.sock ]; then
        fpm_ready=1
        break
    fi
    if ! kill -0 "$fpm_pid" 2>/dev/null; then
        break
    fi
    sleep 1
done
[ "$fpm_ready" -eq 1 ]

apachectl -DFOREGROUND >"$apache_log" 2>&1 &
apache_pid=$!
status=
curl_rc=0
for _ in $(seq 1 30); do
    if status=$(curl --fail -sS -o "$body_file" -w '%{http_code}' http://127.0.0.1/index.php); then
        curl_rc=0
    else
        curl_rc=$?
    fi
    if [ "$status" = "503" ]; then
        break
    fi
    sleep 1
done

[ "$status" = "503" ]
[ "$curl_rc" -ne 0 ]
grep -F 'Permission denied' /var/log/apache2/error.log >/dev/null
