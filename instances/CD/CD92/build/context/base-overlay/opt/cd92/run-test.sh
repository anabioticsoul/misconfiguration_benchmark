#!/usr/bin/env bash
set -euo pipefail
cd /opt/cd92
rm -rf logs
mkdir -p logs
java -Dlogback.configurationFile=/opt/cd92/logback.xml -cp /opt/cd92/classes:/usr/share/java/logback-classic.jar:/usr/share/java/logback-core.jar:/usr/share/java/slf4j-api.jar LogBurst 10000
java -Dlogback.configurationFile=/opt/cd92/logback.xml -cp /opt/cd92/classes:/usr/share/java/logback-classic.jar:/usr/share/java/logback-core.jar:/usr/share/java/slf4j-api.jar LogBurst 10000
archives=$(find /opt/cd92/logs -maxdepth 1 -type f -name '*.gz' | wc -l)
if [ "$archives" -lt 2 ]; then
  echo "expected at least two archived gzip files, found $archives" >&2
  exit 1
fi
[ -s /opt/cd92/logs/last.log ]
