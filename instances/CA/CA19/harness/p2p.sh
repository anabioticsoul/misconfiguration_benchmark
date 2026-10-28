#!/usr/bin/env bash
set -euo pipefail
test -x /opt/ca19/SurveyClient.exe
test -f /opt/ca19/SurveyClient.exe.config
mono --version > /tmp/ca19-mono-version.txt
grep -Fq "Mono" /tmp/ca19-mono-version.txt
