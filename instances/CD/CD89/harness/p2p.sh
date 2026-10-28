#!/usr/bin/env bash
set -euo pipefail

log_file=/tmp/cd89-logs/CernerPharmacyWebApp.log
startup_log=/tmp/cd89-p2p-startup.log
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
    echo "Log4j2 did not create the configured log file" >&2
    exit 1
fi
if ! grep -F 'BARCODE_ORDER_EVENT' "$log_file" >/dev/null; then
    echo "the barcode-order event was not emitted" >&2
    cat "$log_file" >&2
    exit 1
fi
if [ ! -s /opt/cd89/log4j2.xml ]; then
    echo "the application configuration disappeared" >&2
    exit 1
fi
