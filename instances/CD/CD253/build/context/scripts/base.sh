#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends apache2 ca-certificates curl build-essential autoconf bison re2c pkg-config libxml2-dev

work=/tmp/php-build
rm -rf "$work"
mkdir -p "$work"
curl -fsSL https://www.php.net/distributions/php-7.4.33.tar.gz -o "$work/php.tar.gz"
tar -xzf "$work/php.tar.gz" -C "$work"
cd "$work/php-7.4.33"
./configure --prefix=/usr/local/php7.4 --sysconfdir=/etc/php/7.4 --with-config-file-path=/etc/php/7.4/cli --enable-cli --enable-fpm --disable-cgi --disable-all
make -j"$(nproc)"
make install

ln -s /usr/local/php7.4/bin/php /usr/local/bin/php
ln -s /usr/local/php7.4/sbin/php-fpm /usr/local/bin/php-fpm7.4
mkdir -p /etc/php/7.4/fpm/pool.d /etc/php/7.4/cli /run/php

if ! getent group shell_user >/dev/null; then
    groupadd --system shell_user
fi
if ! id -u shell_user >/dev/null 2>&1; then
    useradd --system --gid shell_user --home-dir /home/shell_user --create-home --shell /bin/bash shell_user
fi

sed -i 's/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER=shell_user/' /etc/apache2/envvars
sed -i 's/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=shell_user/' /etc/apache2/envvars

a2dismod mpm_event >/dev/null 2>&1 || true
a2enmod mpm_prefork proxy proxy_fcgi setenvif >/dev/null

cat > /etc/php/7.4/fpm/php-fpm.conf <<'EOF'
[global]
pid = /run/php/php7.4-fpm.pid
error_log = /var/log/php7.4-fpm.log
include=/etc/php/7.4/fpm/pool.d/*.conf
EOF

cat > /etc/php/7.4/fpm/pool.d/www.conf <<'EOF'
[www]
user = shell_user
group = shell_user

listen = /run/php/php7.4-fpm.sock
listen.owner = shell_user
listen.group = shell_user
listen.mode = 0660

pm = ondemand
pm.max_children = 5
pm.process_idle_timeout = 10s
pm.max_requests = 100
clear_env = no
security.limit_extensions = .php
EOF

cat > /etc/apache2/sites-available/000-default.conf <<'EOF'
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>

    ProxyPassMatch "^/(.*\\.php(/.*)?)$" "unix:/run/php/php7.4-fpm.sock|fcgi://localhost/var/www/html/"

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

cat > /var/www/html/index.php <<'EOF'
<?php
echo "cd253-ok\\n";
?>
EOF

chown shell_user:shell_user /var/www/html/index.php
chmod 0644 /var/www/html/index.php
/usr/local/php7.4/sbin/php-fpm -t -y /etc/php/7.4/fpm/php-fpm.conf
apachectl -t

cd /
rm -rf "$work"
apt-get purge -y build-essential autoconf bison re2c pkg-config libxml2-dev >/dev/null
apt-get autoremove -y >/dev/null
rm -rf /var/lib/apt/lists/*
