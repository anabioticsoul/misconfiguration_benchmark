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
if [ "$status" -ne 0 ]; then
  echo "Rector command failed unexpectedly" >&2
  exit 1
fi
if ! grep -Fq "User.php" "$output_file"; then
  echo "Rector did not process the entity" >&2
  exit 1
fi
if grep -Fq "#[ORM\\Entity]" "$output_file"; then
  echo "Rector unexpectedly detected an annotation conversion" >&2
  exit 1
fi
