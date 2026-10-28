#!/usr/bin/env bash
set -euo pipefail
command -v gcc >/dev/null
[ -x "$(command -v gcc)" ]
version_output=$(gcc --version)
printf '%s\n' "$version_output" | grep 'gcc' >/dev/null
[ -f /etc/profile.d/cd81-locale.sh ]
