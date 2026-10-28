#!/usr/bin/env bash
set -euo pipefail
test -L /etc/apache2/sites-enabled/ca130.conf
test -f /etc/apache2/ssl/ca130.key
openssl x509 -in /etc/apache2/ssl/ca130.crt -noout -subject >/dev/null
grep -Eq '^[[:space:]]*SSLEngine[[:space:]]+on' /etc/apache2/sites-available/ca130.conf
grep -Eq '^[[:space:]]*SSLCertificateKeyFile[[:space:]]+/etc/apache2/ssl/ca130\.key' /etc/apache2/sites-available/ca130.conf
test -f /usr/lib/apache2/modules/mod_ssl.so
