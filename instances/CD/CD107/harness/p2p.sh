#!/usr/bin/env bash
set -euo pipefail
test -f /opt/cd107/application.properties
test -f /opt/cd107/target/classes/bench/App.class
test -s /opt/cd107/classpath
