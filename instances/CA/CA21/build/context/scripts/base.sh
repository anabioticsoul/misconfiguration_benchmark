#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends openjdk-11-jdk-headless maven ca-certificates
cd /opt/ca21
mvn -q package
cp target/ca21-1.0-jar-with-dependencies.jar app.jar
rm -rf target /root/.m2/repository
