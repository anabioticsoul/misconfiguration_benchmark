#!/usr/bin/env bash
set -euo pipefail
work=/tmp/cd81-f2p
rm -rf "$work"
mkdir -p "$work"
cat >"$work/fixture.c" <<'EOF'
int main(void) {
    int value = 999999999999LL;
    return value == 0;
}
EOF
set +e
output=$(bash -lc 'source /etc/profile; gcc -Wall -Woverflow /tmp/cd81-f2p/fixture.c -o /tmp/cd81-f2p/fixture' 2>&1)
status=$?
set -e
[ "$status" -eq 0 ]
printf '%s\n' "$output"
if printf '%s\n' "$output" | grep 'предупреждение' >/dev/null; then
  exit 1
fi
printf '%s\n' "$output" | grep -F 'warning:' >/dev/null
