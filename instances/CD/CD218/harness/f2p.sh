#!/usr/bin/env bash
set -euo pipefail

output=""
set +e
output="$(php -d display_errors=0 -r '
if (!extension_loaded("xdebug")) {
    fwrite(STDERR, "Xdebug extension is missing\n");
    exit(2);
}
xdebug_break();
if (strpos((string) ini_get("xdebug.mode"), "debug") === false) {
    fwrite(STDERR, "Xdebug debugger mode is not enabled\n");
    exit(1);
}
echo "Xdebug debugger mode is enabled\n";
' 2>&1)"
status=$?
set -e

printf '%s\n' "$output"
exit "$status"
