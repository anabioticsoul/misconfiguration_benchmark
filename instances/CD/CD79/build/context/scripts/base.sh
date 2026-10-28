#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends apache2 curl ca-certificates
rm -rf /var/lib/apt/lists/*
mkdir -p /srv/custom-root
cat > /srv/custom-root/index.html <<'EOF'
custom-root-ok
EOF
cat > /etc/apache2/sites-available/000-default.conf <<'EOF'
<VirtualHost *:80>
    DocumentRoot /srv/custom-root
    <Directory /srv/custom-root>
        Require all granted
        DirectoryIndex index.html
    </Directory>
</VirtualHost>
EOF
sed -i 's/^Listen 80$/Listen 80/' /etc/apache2/ports.conf
