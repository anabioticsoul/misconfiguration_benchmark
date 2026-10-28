#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y openjdk-11-jdk maven curl ca-certificates
update-alternatives --set java "$(echo /usr/lib/jvm/java-11-openjdk-*/bin/java)"
update-alternatives --set javac "$(echo /usr/lib/jvm/java-11-openjdk-*/bin/javac)"
mkdir -p /opt/ca11
cp /pom.xml /opt/ca11/pom.xml
cp -R /src /opt/ca11/src
cd /opt/ca11
mvn -B -DskipTests package
mkdir -p /opt/ca11
cp target/ca11-1.0.0.jar /opt/ca11/app.jar
rm -rf target ~/.m2
