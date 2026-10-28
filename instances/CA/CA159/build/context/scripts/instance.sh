#!/usr/bin/env bash
set -euo pipefail
apache2ctl -f /etc/apache2/ca159.conf -t
