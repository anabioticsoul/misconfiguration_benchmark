#!/usr/bin/env bash
set -euo pipefail
cd /opt/rector-demo
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT
set +e
vendor/bin/rector process src/Entity --dry-run --debug >"$output_file" 2>&1
status=$?
set -e
cat "$output_file"
[ "$status" -eq 0 ] || { echo "Rector failed" >&2; exit 1; }
grep -Fq "User.php" "$output_file"
grep -Fq "#[ORM\\Entity]" "$output_file" || {
  echo "Rector did not report the Doctrine annotation conversion" >&2
  exit 1
}
