#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends php-cli
rm -rf /var/lib/apt/lists/*

mkdir -p /var/www/html/.ddev/php \
  /var/www/html/config/etc/php7/conf.d \
  /usr/local/lib/ca139 \
  /etc/php/8.1/cli/conf.d

cat > /etc/php/8.1/cli/conf.d/99-ca139-ddev-default.ini <<'EOF'
[PHP]
memory_limit = 1G
EOF

cat > /var/www/html/.ddev/php/memlimit.ini <<'EOF'
[PHP]
memory_limit = 2G
EOF

cat > /usr/local/lib/ca139/export.php <<'EOF'
<?php
declare(strict_types=1);

$bytes = 1050 * 1024 * 1024;
$payload = str_repeat('P', $bytes);
if (strlen($payload) !== $bytes) {
    fwrite(STDERR, "export payload length mismatch\n");
    exit(2);
}
fwrite(STDOUT, "export-ok {$bytes}\n");
EOF

cat > /usr/local/bin/ca139-export <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

export PHP_INI_SCAN_DIR="/etc/php/8.1/cli/conf.d:/var/www/html/.ddev/php"
exec /usr/bin/php /usr/local/lib/ca139/export.php "$@"
EOF
chmod 0755 /usr/local/bin/ca139-export
