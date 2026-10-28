#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends apache2 openssl ca-certificates
rm -rf /var/lib/apt/lists/*

install -d -m 0755 /etc/apache2/ssl.crt /var/www/html

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout /tmp/ca129-ca.key \
  -out /etc/apache2/ssl.crt/ca129-ca.crt \
  -days 3650 -subj "/CN=CA129 Test CA"
openssl req -new -newkey rsa:2048 -nodes \
  -keyout /etc/apache2/ssl.crt/server.key \
  -out /tmp/ca129-server.csr \
  -subj "/CN=my-domain.com"
openssl x509 -req -in /tmp/ca129-server.csr \
  -CA /etc/apache2/ssl.crt/ca129-ca.crt \
  -CAkey /tmp/ca129-ca.key -CAcreateserial \
  -out /etc/apache2/ssl.crt/minecraft-multiplayer_com.crt \
  -days 3650 -sha256
cp /etc/apache2/ssl.crt/ca129-ca.crt \
  /etc/apache2/ssl.crt/minecraft-multiplayer_com.ca-bundle
rm -f /tmp/ca129-ca.key /tmp/ca129-server.csr /tmp/ca129-ca.srl

cat > /etc/apache2/sites-available/ca129-ssl.conf <<'EOF'
<IfModule mod_ssl.c>
  <VirtualHost *:443>
    ServerAdmin webmaster@localhost

    ServerName my-domain.com

    DocumentRoot /var/www/html

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    SSLEngine on

    SSLCertificateFile /etc/apache2/ssl.crt/minecraft-multiplayer_com.crt
    SSLCertificateKeyFile /etc/apache2/ssl.crt/server.key
    SSLCertificateChainFile /etc/apache2/ssl.crt/minecraft-multiplayer_com.ca-bundle

    <FilesMatch "\.(cgi|shtml|phtml|php)$">
        SSLOptions +StdEnvVars
    </FilesMatch>
    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>

    BrowserMatch "MSIE [2-6]" \
        nokeepalive ssl-unclean-shutdown \
        downgrade-1.0 force-response-1.0
    BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

  </VirtualHost>
</IfModule>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF

a2enmod ssl
a2dissite 000-default || true
a2dissite default-ssl || true
a2ensite ca129-ssl
if ! grep -Fq 'Listen 443' /etc/apache2/ports.conf; then
  printf '\nListen 443\n' >> /etc/apache2/ports.conf
fi
