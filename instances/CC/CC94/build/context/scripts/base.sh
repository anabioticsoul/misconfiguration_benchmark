#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl unzip git openjdk-17-jdk
mkdir -p /opt/jdks /opt/gradle
machine_arch="$(dpkg --print-architecture)"
case "$machine_arch" in
  amd64) jdk_arch="x64" ;;
  arm64) jdk_arch="aarch64" ;;
  *) echo "Unsupported architecture: $machine_arch" >&2; exit 1 ;;
esac
curl -fsSL "https://api.adoptium.net/v3/binary/latest/8/ga/linux/$jdk_arch/jdk/hotspot/normal/eclipse" -o /tmp/jdk8.tar.gz
tar -xzf /tmp/jdk8.tar.gz -C /opt/jdks
mv /opt/jdks/jdk8u* /opt/jdks/java-8
curl -fsSL 'https://services.gradle.org/distributions/gradle-7.6.1-bin.zip' -o /tmp/gradle.zip
unzip -q /tmp/gradle.zip -d /opt/gradle
ln -s /opt/gradle/gradle-7.6.1/bin/gradle /usr/local/bin/gradle
rm -rf /var/lib/apt/lists/* /tmp/jdk8.tar.gz /tmp/gradle.zip
