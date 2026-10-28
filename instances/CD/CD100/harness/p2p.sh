#!/usr/bin/env bash
set -euo pipefail

command -v /usr/local/bin/vscode-settings-check >/dev/null
/usr/local/bin/vscode-settings-check --verify-globals
