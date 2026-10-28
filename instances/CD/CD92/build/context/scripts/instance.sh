#!/usr/bin/env bash
set -euo pipefail
mkdir -p /opt/cd92/classes /opt/cd92/logs
javac -cp /usr/share/java/logback-classic.jar:/usr/share/java/logback-core.jar:/usr/share/java/slf4j-api.jar -d /opt/cd92/classes /opt/cd92/LogBurst.java
chmod +x /opt/cd92/run-test.sh
