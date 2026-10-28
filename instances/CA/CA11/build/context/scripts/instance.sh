#!/usr/bin/env bash
set -euo pipefail
test -f /opt/ca11/application.properties
test -s /opt/ca11/app.jar
