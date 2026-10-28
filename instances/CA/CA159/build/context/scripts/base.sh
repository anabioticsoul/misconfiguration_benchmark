#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 openssl curl
a2enmod ssl proxy proxy_http proxy_balancer lbmethod_byrequests >/dev/null
mkdir -p /etc/apache2/ssl /var/www/backend1 /var/www/backend2 /run/apache2 /var/log/apache2
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -keyout /etc/apache2/ssl/backend1.key -out /etc/apache2/ssl/backend1.crt -subj '/CN=backend1' >/dev/null 2>&1
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -keyout /etc/apache2/ssl/backend2.key -out /etc/apache2/ssl/backend2.crt -subj '/CN=backend2' >/dev/null 2>&1
printf 'backend-one-ok\n' >/var/www/backend1/test.jsp
printf 'backend-two-ok\n' >/var/www/backend2/test.jsp
cat > /etc/apache2/ca159.conf <<'EOF'
ServerRoot /etc/apache2
PidFile /run/apache2/ca159.pid
ServerName localhost
Listen 8080
Listen 8443
Listen 9443
ErrorLog /var/log/apache2/ca159-error.log
LogLevel proxy:info ssl:info
CustomLog /var/log/apache2/ca159-access.log combined
IncludeOptional /etc/apache2/mods-enabled/*.load
IncludeOptional /etc/apache2/mods-enabled/*.conf

<VirtualHost *:8443>
    ServerName backend1
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/backend1.crt
    SSLCertificateKeyFile /etc/apache2/ssl/backend1.key
    DocumentRoot /var/www/backend1
</VirtualHost>
<VirtualHost *:9443>
    ServerName backend2
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/backend2.crt
    SSLCertificateKeyFile /etc/apache2/ssl/backend2.key
    DocumentRoot /var/www/backend2
</VirtualHost>

Include /etc/apache2/loadbalancer.conf
EOF
cat > /etc/apache2/loadbalancer.conf <<'EOF'
<VirtualHost *:8080>
    ServerName loadbalancer
    SSLProxyEngine on
    SSLProxyVerify optional_no_ca
    SSLProxyCheckPeerCN off
    SSLProxyCheckPeerName off
    ProxyPass /test balancer://testcluster
    ProxyPassReverse /test balancer://testcluster
    <Proxy balancer://testcluster>
        BalancerMember https://127.0.0.1:8443
        BalancerMember https://127.0.0.1:9443
    </Proxy>
</VirtualHost>
EOF
