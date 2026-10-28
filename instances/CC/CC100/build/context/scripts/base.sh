#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends openjdk-11-jdk maven ca-certificates curl
rm -rf /var/lib/apt/lists/*
mkdir -p /opt/cc100
