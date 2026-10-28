#!/usr/bin/env bash
set -euo pipefail
prefs=/opt/eclipse-workspace/.metadata/.plugins/org.eclipse.debug.ui/org.eclipse.debug.ui.prefs
printf 'filterDeletedProjects=true\n' > "$prefs"
