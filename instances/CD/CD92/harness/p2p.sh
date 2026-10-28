#!/usr/bin/env bash
set -euo pipefail
rm -rf /opt/cd92/logs
mkdir -p /opt/cd92/logs
java -Dlogback.configurationFile=/opt/cd92/logback.xml -cp /opt/cd92/classes:/usr/share/java/logback-classic.jar:/usr/share/java/logback-core.jar:/usr/share/java/slf4j-api.jar LogBurst 1
[ -s /opt/cd92/logs/last.log ]
