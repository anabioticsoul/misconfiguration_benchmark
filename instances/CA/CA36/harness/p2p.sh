#!/usr/bin/env bash
set -euo pipefail
vim --version >/dev/null
vim -Nu NONE -n -es -c 'call setline(1, "healthy")' -c 'qa!'
