#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

updated=0
for attempt in 1 2 3 4 5; do
    rm -rf /var/lib/apt/lists/*
    if apt-get \
        -o Acquire::Retries=3 \
        -o Acquire::By-Hash=yes \
        -o Acquire::http::No-Cache=true \
        -o Acquire::http::Timeout=30 \
        update; then
        updated=1
        break
    fi
    if [ "$attempt" -lt 5 ]; then
        sleep 2
    fi
done
[ "$updated" -eq 1 ]
apt-get install -y --no-install-recommends php-cli
rm -rf /var/lib/apt/lists/*

cat > /etc/php/8.1/cli/conf.d/99-ca115.ini <<'INI'
; Keep ordinary warnings visible while suppressing notices and deprecations.
error_reporting = 24567
INI

install -d -m 0755 /opt/ca115
cat > /opt/ca115/app.php <<'PHP'
<?php
$missing = $ca115_undefined;
$deprecated = strlen(null);
if ((error_reporting() & E_DEPRECATED) !== 0) {
    exit(1);
}
echo "CA115 application completed\n";
exit(0);
PHP
chmod 0644 /opt/ca115/app.php
