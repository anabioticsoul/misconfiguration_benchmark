#!/usr/bin/env bash
set -euo pipefail

command -v /usr/local/bin/vscode-settings-check >/dev/null
set +e
output="$(/usr/local/bin/vscode-settings-check --language python --expect-tab-size 4 --expect-insert-spaces true 2>&1)"
status=$?
set -e
printf '%s\n' "$output"
if [ "$status" -ne 0 ]; then
  printf '%s\n' "Python language-specific settings are not configured" >&2
  exit 1
fi
case "$output" in
  *"language-specific settings valid for python"*) exit 0 ;;
  *)
    printf '%s\n' "unexpected successful validation output" >&2
    exit 1
    ;;
esac
