#!/usr/bin/env bash
set -euo pipefail
launch=/opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.core/.launches/Equivalence_Checker.launch
test -f "$launch"
grep -F 'Equivalence Checker' "$launch" >/dev/null
