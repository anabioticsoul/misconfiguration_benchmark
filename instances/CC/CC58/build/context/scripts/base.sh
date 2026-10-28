#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends openjdk-17-jdk-headless maven ca-certificates
cd /opt/camel
mvn -q -DskipTests package
classpath="target/classes"
while IFS= read -r jar; do
  classpath="$classpath:$jar"
done < <(find "$HOME/.m2/repository" -type f -name '*.jar' | sort)
java -cp "$classpath" com.example.Main
rm -rf /var/lib/apt/lists/*
