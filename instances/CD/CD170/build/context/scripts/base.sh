#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates python3 python3-pip
python3 -m pip install --no-cache-dir 'Django==4.2.16'
chmod +x /opt/cd170/manage.py /opt/cd170/run.sh
