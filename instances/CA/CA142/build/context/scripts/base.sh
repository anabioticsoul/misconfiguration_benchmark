#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates openjdk-11-jdk-headless wget
rm -rf /var/lib/apt/lists/*
mkdir -p /opt/flink/lib /opt/flink/bin
wget -q -O /opt/flink/lib/aws-java-sdk-bundle-1.12.31.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.31/aws-java-sdk-bundle-1.12.31.jar
javac --add-modules jdk.httpserver -cp /opt/flink/lib/aws-java-sdk-bundle-1.12.31.jar -d /opt/flink/bin /opt/flink/bin/CheckpointProbe.java
chmod 0755 /opt/flink/bin/checkpoint-probe
