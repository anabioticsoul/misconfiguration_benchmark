#!/usr/bin/env bash
set -euo pipefail
test -x /opt/springboot/run.sh
test -s /opt/springboot/classes/net/guides/springboot2/crud/Application.class
java -version 2>&1 | grep -F 'version'
