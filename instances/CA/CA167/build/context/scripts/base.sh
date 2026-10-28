#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends apache2 ca-certificates curl
rm -rf /var/lib/apt/lists/*
mkdir -p /run/apache2
apachectl configtest
