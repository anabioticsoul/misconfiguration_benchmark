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
' 2>&1)"
status=$?
set -e

printf '%s\n' "$output"
if [ "$status" -eq 0 ]; then
    printf '%s\n' 'Expected the Xdebug debugger operation to fail before repair.' >&2
    exit 1
fi
case "$output" in
    *'Xdebug debugger mode is not enabled'*) exit 0 ;;
    *)
        printf '%s\n' 'The expected Xdebug debugger symptom was not observed.' >&2
        exit 1
        ;;
esac
