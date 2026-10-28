#!/usr/bin/env bash
set -euo pipefail
mkdir -p /var/lib/nginx/tmp
chown -R nginx:nginx /var/lib/nginx/tmp
chown root:root /var/lib/nginx
chmod 0700 /var/lib/nginx
# The leaf looks writable, but nginx cannot traverse its parent.
chmod 0777 /var/lib/nginx/tmp
