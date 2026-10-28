#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl gcc make perl libc6-dev libexpat1-dev libpcre3-dev zlib1g-dev \
  libapr1-dev libaprutil1-dev curl

work=/usr/local/src/apache-build
rm -rf "$work"
mkdir -p "$work"
cd "$work"

curl -fsSLo httpd.tar.gz https://archive.apache.org/dist/httpd/httpd-2.4.34.tar.gz
curl -fsSLo apr.tar.gz https://archive.apache.org/dist/apr/apr-1.6.5.tar.gz
curl -fsSLo apr-util.tar.gz https://archive.apache.org/dist/apr/apr-util-1.6.1.tar.gz

tar -xzf httpd.tar.gz
tar -xzf apr.tar.gz
tar -xzf apr-util.tar.gz
mv apr-1.6.5 httpd-2.4.34/srclib/apr
mv apr-util-1.6.1 httpd-2.4.34/srclib/apr-util

cd httpd-2.4.34
./configure \
  --prefix=/opt/apache \
  --enable-so \
  --enable-mpms-shared=worker \
  --with-mpm=worker \
  --enable-mods-shared=most
make -j"$(getconf _NPROCESSORS_ONLN)"
make install

/opt/apache/bin/apxs -c -i /usr/local/src/mod_stackprobe.c

mkdir -p /opt/apache/htdocs /opt/apache/logs
cat > /opt/apache/htdocs/index.html <<'EOF'
Apache CB58 health endpoint
EOF
cat > /opt/apache/conf/httpd.conf <<'EOF'
ServerRoot "/opt/apache"
Listen 8080

LoadModule mpm_worker_module modules/mod_mpm_worker.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule dir_module modules/mod_dir.so
LoadModule log_config_module modules/mod_log_config.so
LoadModule mime_module modules/mod_mime.so
LoadModule unixd_module modules/mod_unixd.so
LoadModule stackprobe_module modules/mod_stackprobe.so

ServerName localhost
PidFile logs/httpd.pid
ErrorLog logs/error_log
LogLevel notice
CustomLog logs/access_log combined
DocumentRoot "/opt/apache/htdocs"

<Directory "/opt/apache/htdocs">
    AllowOverride None
    Require all granted
</Directory>

<Location "/stackprobe">
    SetHandler stackprobe-handler
</Location>

<IfModule mpm_worker_module>
    StartServers 1
    MinSpareThreads 1
    MaxSpareThreads 4
    ThreadsPerChild 4
    MaxRequestWorkers 4
    MaxConnectionsPerChild 0
    ThreadStackSize 8888888
</IfModule>
EOF

/opt/apache/bin/httpd -t -f /opt/apache/conf/httpd.conf
rm -rf "$work"
apt-get clean
rm -rf /var/lib/apt/lists/*
