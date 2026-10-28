#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl
rm -rf /var/lib/apt/lists/*

mkdir -p /home/ubuntu/virtualenv/myapp/error
mkdir -p /home/ubuntu/virtualenv/myapp/myapp/homelaunch/static/css
mkdir -p /home/ubuntu/virtualenv/myapp/myapp/homelaunch/static/img/templated/home
chown -R root:root /home/ubuntu/virtualenv
find /home/ubuntu/virtualenv -type d -exec chmod 0755 {} \;
find /home/ubuntu/virtualenv -type f -exec chmod 0644 {} \;
