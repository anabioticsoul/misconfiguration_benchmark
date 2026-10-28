#!/usr/bin/env bash
set -euo pipefail
set +e
output=$(/usr/local/bin/eclipse-config-check /opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.core/.launches 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -ne 0 ]
case "$output" in
  *'A configuration with this name already exists'*) ;;
  *) exit 1 ;;
esac
