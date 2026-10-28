#!/usr/bin/env bash
set -euo pipefail
work=/tmp/cd81-repro
rm -rf "$work"
mkdir -p "$work"
cat >"$work/fixture.c" <<'EOF'
#include <limits.h>
int main(void) {
    int value = 999999999999LL;
    return value == 0;
}
EOF
set +e
output=$(bash -lc 'source /etc/profile; gcc -Wall -Woverflow /tmp/cd81-repro/fixture.c -o /tmp/cd81-repro/fixture' 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -eq 0 ]
printf '%s\n' "$output" | grep 'предупреждение' >/dev/null
