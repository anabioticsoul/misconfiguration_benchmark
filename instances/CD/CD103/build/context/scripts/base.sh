#!/usr/bin/env bash
set -euo pipefail
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends php-fpm curl
rm -rf /var/lib/apt/lists/*
mkdir -p /var/www/example.com /run/php /etc/nginx/conf.d
rm -f /etc/nginx/conf.d/default.conf
cat > /var/www/example.com/index.php <<'PHP'
<?php
http_response_code(200);
header('Content-Type: text/plain');
echo "Drupal front controller\n";
PHP
cat > /var/www/example.com/not-found.php <<'PHP'
<?php
http_response_code(404);
header('Content-Type: text/plain');
echo "Drupal 404 page\n";
PHP
cat > /etc/php/8.2/fpm/pool.d/www.conf <<'EOF'
[www]
user = www-data
group = www-data
listen = /run/php/php-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = static
pm.max_children = 4
clear_env = no
EOF
cat > /usr/local/bin/cd103-start <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
php-fpm8.2 -F > /tmp/php-fpm.log 2>&1 &
fpm_pid=$!
for i in $(seq 1 50); do
  test -S /run/php/php-fpm.sock && break
  kill -0 "$fpm_pid" 2>/dev/null || { cat /tmp/php-fpm.log >&2; exit 1; }
  sleep 0.1
done
test -S /run/php/php-fpm.sock
exec nginx -g 'daemon off;'
EOF
chmod +x /usr/local/bin/cd103-start
