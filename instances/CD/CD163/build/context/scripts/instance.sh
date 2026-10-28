#!/usr/bin/env bash
set -euo pipefail
install -d /var/log/cd163
cat > /usr/local/bin/cd163-entrypoint.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export APACHE_CONFDIR="${APACHE_CONFDIR:-/etc/apache2}"
. /etc/apache2/envvars
mkdir -p /var/log/cd163 "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR"
php -S 127.0.0.1:9000 -t /var/www/html >>/var/log/cd163/php-server.log 2>&1 &
printf '%s\n' "$!" >/var/run/cd163-php.pid
exec apache2 -D FOREGROUND
EOF
chmod 0755 /usr/local/bin/cd163-entrypoint.sh
apache2ctl configtest
