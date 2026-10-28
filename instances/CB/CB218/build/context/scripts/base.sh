#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends openjdk-11-jdk-headless
javac -d /opt/ted-search /opt/ted-search/App.java
rm /opt/ted-search/App.java
chmod -R a+rX /opt/ted-search
rm -rf /var/lib/apt/lists/*
