#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends php8.1-cli php8.1-curl ca-certificates
rm -rf /var/lib/apt/lists/*

curl_link="$(dpkg-query -L libcurl4 | awk '$0 ~ /\/libcurl\.so\.4$/ { found=$0 } END { print found }')"
if [ -z "$curl_link" ] || [ ! -e "$curl_link" ]; then
  echo "Unable to locate the installed libcurl.so.4 symlink" >&2
  exit 1
fi
curl_dir="$(dirname "$curl_link")"
curl_target="$(readlink "$curl_link")"
if [ "${curl_target#/}" = "$curl_target" ]; then
  curl_target="$curl_dir/$curl_target"
fi
if [ ! -f "$curl_target" ]; then
  echo "Unable to locate the installed libcurl target" >&2
  exit 1
fi

install -d /opt/php/lib
mv "$curl_target" /opt/php/lib/
rm "$curl_link"
ln -s "$(basename "$curl_target")" /opt/php/lib/libcurl.so.4
ldconfig
export LD_LIBRARY_PATH=/opt/php/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

php -m > /tmp/php-modules.txt
if ! grep -F -x -e curl /tmp/php-modules.txt > /dev/null; then
  echo "The PHP cURL extension was not enabled during the base build" >&2
  exit 1
fi
rm -f /tmp/php-modules.txt
