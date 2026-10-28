#!/usr/bin/env bash
set -euo pipefail
cd /opt/camel
classpath="target/classes"
while IFS= read -r jar; do
  case "$jar" in
    *camel-spring-xml-3.22.4.jar) ;;
    *) classpath="$classpath:$jar" ;;
  esac
done < <(find "$HOME/.m2/repository" -type f -name '*.jar' | sort)
set +e
output=$(java -cp "$classpath" com.example.Main 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -ne 0 ]
printf '%s' "$output" | grep -F 'Unable to locate Spring NamespaceHandler'
printf '%s' "$output" | grep -F 'http://camel.apache.org/schema/spring'
