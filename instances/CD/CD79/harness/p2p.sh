#!/usr/bin/env bash
set -euo pipefail
apache2ctl -t
[ -f /srv/custom-root/index.html ]
[ "$(apache2ctl -S 2>&1 | grep -c '000-default.conf')" -ge 1 ]
