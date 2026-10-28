#!/usr/bin/env bash
set -euo pipefail
body="$(curl -sS -o - -w '\n%{http_code}' http://127.0.0.1/index.php)"
code="${body##*$'\n'}"
content="${body%$'\n'*}"
test "$code" = 200
grep -Fq "Drupal front controller" <<<"$content"
