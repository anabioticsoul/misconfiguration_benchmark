#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends apache2 apache2-utils ca-certificates
rm -rf /var/lib/apt/lists/*
mkdir -p /var/www/html/writing
printf 'protected apache content\n' > /var/www/html/writing/index.html
htpasswd -bc /etc/apache2/.htpasswd benchmark secret >/dev/null
cat > /var/www/html/writing/.htaccess <<'EOF'
AuthType Basic
AuthName "Writing"
AuthUserFile /etc/apache2/.htpasswd
Require valid-user
EOF
cat > /etc/apache2/conf-available/cc53-writing.conf <<'EOF'
<Directory /var/www/html/writing>
    AllowOverride AuthConfig
    Options -Indexes
</Directory>
EOF
a2enconf cc53-writing >/dev/null
printf 'ServerName localhost\n' > /etc/apache2/conf-available/cc53-servername.conf
a2enconf cc53-servername >/dev/null
# Keep the container as an investigation shell; harnesses start Apache explicitly.
rm -f /var/run/apache2/apache2.pid
