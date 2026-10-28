#!/usr/bin/env bash
set -euo pipefail
mkdir -p /etc/php/8.1/cli/conf.d
printf '%s\n' 'memory_limit = 4M' > /etc/php/8.1/cli/conf.d/99-cb210-memory.ini
