#!/usr/bin/env bash
set -euo pipefail
cd /opt/cc69
grep -F '<artifactId>spring-orm</artifactId>' pom.xml >/dev/null
grep -F '<version>5.3.19</version>' pom.xml >/dev/null
grep -F '<artifactId>hibernate-core</artifactId>' pom.xml >/dev/null
test -f src/main/java/example/App.java
