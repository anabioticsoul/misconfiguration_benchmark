#!/usr/bin/env bash
set -euo pipefail

config=/etc/apache2/sites-available/ca129-ssl.conf
key=/etc/apache2/ssl.crt/server.key
cert=/etc/apache2/ssl.crt/minecraft-multiplayer_com.crt
chain=/etc/apache2/ssl.crt/minecraft-multiplayer_com.ca-bundle

test -s "$config"
test -L /etc/apache2/mods-enabled/ssl.load
test -L /etc/apache2/sites-enabled/ca129-ssl.conf
test -s "$key"
test -s "$cert"
test -s "$chain"

grep -F 'ServerName my-domain.com' "$config" >/dev/null
grep -F 'DocumentRoot /var/www/html' "$config" >/dev/null
grep -F 'SSLEngine on' "$config" >/dev/null
grep -F 'SSLCertificateKeyFile /etc/apache2/ssl.crt/server.key' "$config" >/dev/null

openssl x509 -in "$cert" -noout >/dev/null
openssl rsa -in "$key" -check -noout >/dev/null 2>&1
