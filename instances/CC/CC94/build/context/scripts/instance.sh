#!/usr/bin/env bash
set -euo pipefail
chmod +x /opt/cc94/app/gradlew
java_home="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
cd /opt/cc94/app
JAVA_HOME="$java_home" /opt/gradle/gradle-7.6.1/bin/gradle build -x check --no-daemon
rm -rf /opt/cc94/app/build
