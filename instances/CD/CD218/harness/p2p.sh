#!/usr/bin/env bash
set -euo pipefail

output="$(php -d display_errors=0 -r '
if (!extension_loaded("xdebug")) {
    fwrite(STDERR, "Xdebug extension is missing\n");
    exit(1);
}
echo "Xdebug extension loaded\n";
')"
printf '%s\n' "$output"
case "$output" in
    *'Xdebug extension loaded'*) ;;
    *) printf '%s\n' 'Xdebug extension did not remain loadable.' >&2; exit 1 ;;
esac
