#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends openjdk-11-jdk-headless liblogback-java libslf4j-java
rm -rf /var/lib/apt/lists/*
