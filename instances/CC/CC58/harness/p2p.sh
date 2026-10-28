#!/usr/bin/env bash
set -euo pipefail
cd /opt/camel
test -f pom.xml
test -f src/main/resources/spring.xml
grep -F '<camelContext' src/main/resources/spring.xml >/dev/null
mvn -o -q -DskipTests package
