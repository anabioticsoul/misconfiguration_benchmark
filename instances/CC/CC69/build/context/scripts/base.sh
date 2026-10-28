#!/usr/bin/env bash
set -euo pipefail
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y maven openjdk-17-jdk-headless
cd /opt/cc69
mvn -q -DskipTests compile dependency:go-offline
