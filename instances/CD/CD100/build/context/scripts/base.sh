#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends python3
rm -rf /var/lib/apt/lists/*
chmod 0755 /usr/local/bin/vscode-settings-check
