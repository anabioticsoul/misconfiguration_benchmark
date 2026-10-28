#!/usr/bin/env bash
set -euo pipefail
output=$(/usr/local/bin/eclipse-config-check /opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.core/.launches 2>&1)
printf '%s\n' "$output"
[ "$output" = "Equivalence Checker configuration is discoverable" ]
