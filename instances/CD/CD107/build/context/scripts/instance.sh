#!/usr/bin/env bash
set -euo pipefail
cd /opt/cd107
mvn -q -DskipTests package dependency:build-classpath -Dmdep.outputFile=/opt/cd107/classpath
chmod -R a+rX /opt/cd107
