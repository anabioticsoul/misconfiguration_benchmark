#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# Minimal Ubuntu images discard message catalogs even for installed locale packages.
if [ -f /etc/dpkg/dpkg.cfg.d/excludes ]; then
  sed -i '\|^path-exclude=/usr/share/locale/\*/LC_MESSAGES/\*.mo$|d' /etc/dpkg/dpkg.cfg.d/excludes
fi
apt-get update
apt-get install -y --no-install-recommends gcc gcc-11-locales libc6-dev locales bash ca-certificates git
test -s /usr/share/locale/ru/LC_MESSAGES/gcc-11.mo
sed -i '/^[# ]*en_GB.UTF-8 UTF-8/s/^# *//' /etc/locale.gen
sed -i '/^[# ]*ru_RU.UTF-8 UTF-8/s/^# *//' /etc/locale.gen
locale-gen en_GB.UTF-8 ru_RU.UTF-8
rm -rf /var/lib/apt/lists/*
mkdir -p /etc/profile.d
