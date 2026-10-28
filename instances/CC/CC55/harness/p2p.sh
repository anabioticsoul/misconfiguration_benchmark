#!/usr/bin/env bash
set -euo pipefail

project=/opt/intellij-fixture/project
[ -f "$project/pom.xml" ]
[ -f "$project/src/main/resources/applicationContext.xml" ]
[ -s "$project/src/main/resources/applicationContext.xml" ]
grep -Fq '<artifactId>spring-facet-fixture</artifactId>' "$project/pom.xml"
grep -Fq '<beans ' "$project/src/main/resources/applicationContext.xml"
grep -Fq 'fixtureMarker' "$project/src/main/resources/applicationContext.xml"
