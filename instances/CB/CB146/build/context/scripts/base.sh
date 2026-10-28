#!/usr/bin/env bash
set -euo pipefail
mkdir -p /opt/laravel /opt/laravel/bin /opt/laravel/config
cat > /opt/laravel/artisan <<'ARTISAN'
#!/usr/bin/env bash
set -euo pipefail
config=/opt/laravel/config/database.php
socket=$(awk -F"'" '/unix_socket/ {print $4; exit}' "$config")
[ "${1:-}" = migrate ] || { echo "Unsupported artisan command" >&2; exit 2; }
exec mysql --protocol=socket --socket="$socket" -u homestead -psecret homestead -e 'CREATE TABLE IF NOT EXISTS migrations (id INT PRIMARY KEY);'
ARTISAN
chmod 755 /opt/laravel/artisan
