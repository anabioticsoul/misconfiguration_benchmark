#!/usr/bin/env bash
set -euo pipefail

static_root=/home/ubuntu/virtualenv/myapp/myapp/homelaunch/static
chmod 0700 "$static_root"
chmod 0600 "$static_root/css/site.css"
chmod 0600 "$static_root/img/templated/home/img.png"
