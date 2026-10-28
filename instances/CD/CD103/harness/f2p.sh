#!/usr/bin/env bash
set -euo pipefail
url="http://127.0.0.1/this-file-doesnt-exist.php"
body="$(curl -sS -o - -w '\n%{http_code}' "$url")"
code="${body##*$'\n'}"
content="${body%$'\n'*}"
printf '%s\n' "$content"
test "$code" = 200
grep -Fq "Drupal front controller" <<<"$content"
! grep -Fq "File not found" <<<"$content"
