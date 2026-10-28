#!/usr/bin/env bash
set -euo pipefail

log_file=/tmp/cd89-logs/CernerPharmacyWebApp.log
startup_log=/tmp/cd89-repro-startup.log
rm -rf /tmp/cd89-logs
mkdir -p /tmp/cd89-logs
: > "$startup_log"

set +e
java -cp /opt/cd89/classes:/usr/share/java/log4j-api.jar:/usr/share/java/log4j-core.jar \
  -Dlog4j.configurationFile=/opt/cd89/log4j2.xml \
  com.jarmel.pharmacy.controls.BarCodeOrderServlet >"$startup_log" 2>&1
status=$?
set -e
if [ "$status" -ne 0 ]; then
    cat "$startup_log" >&2
    exit 1
fi

if [ ! -f "$log_file" ]; then
    cat "$startup_log" >&2
    echo "expected Log4j2 output file was not created" >&2
    exit 1
fi
count=$(awk '/BARCODE_ORDER_EVENT/ { n++ } END { print n + 0 }' "$log_file")
if [ "$count" -ne 2 ]; then
    echo "expected duplicate log lines, observed: $count" >&2
    exit 1
fi
echo "duplicate log lines observed: $count" >&2
