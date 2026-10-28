#!/usr/bin/env bash
set -euo pipefail
cd /opt/camel
classpath="target/classes"
while IFS= read -r jar; do
  case "$jar" in
    *camel-spring-xml-3.22.4.jar)
      grep -F 'camel-spring-xml' pom.xml >/dev/null || continue
      ;;
  esac
  classpath="$classpath:$jar"
done < <(find "$HOME/.m2/repository" -type f -name '*.jar' | sort)
output=$(java -cp "$classpath" com.example.Main 2>&1)
printf '%s\n' "$output"
printf '%s' "$output" | grep -F 'SPRING_CONTEXT_LOADED'
