#!/usr/bin/env bash
set -euo pipefail
cd /opt/cc94/app
./gradlew build -x check --offline
 test -f build/libs/RnR-0.0.1-SNAPSHOT.jar
