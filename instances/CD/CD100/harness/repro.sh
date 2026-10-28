#!/usr/bin/env bash
set -euo pipefail

command -v /usr/local/bin/vscode-settings-check >/dev/null
if output="$(/usr/local/bin/vscode-settings-check --language python --expect-tab-size 4 --expect-insert-spaces true 2>&1)"; then
  status=0
else
  status=$?
fi
printf '%s\n' "$output"
case "$output" in
  *"language-specific settings missing for python"*)
    if [ "$status" -eq 0 ]; then
      printf '%s\n' "validator unexpectedly accepted missing Python settings" >&2
      exit 1
    fi
    exit 0
    ;;
  *)
    printf '%s\n' "unexpected settings validation output" >&2
    exit 1
    ;;
esac
