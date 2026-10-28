#!/usr/bin/env bash
set -euo pipefail
cd /opt/cc94/app
grep -F "org.springframework.boot' version '3.1.0" build.gradle
grep -F 'gradle-7.6.1' gradlew
[ "$(grep -c '^java.runtime.version=' system.properties)" -eq 1 ]
