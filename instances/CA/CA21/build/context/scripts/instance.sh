#!/usr/bin/env bash
set -euo pipefail
cd /opt/ca21
mvn -q package
cp target/ca21-1.0-jar-with-dependencies.jar app.jar
rm -rf target
