#!/usr/bin/env bash
set -euo pipefail
cd /opt/cc100
mvn -q -DskipTests package
cat > /usr/local/bin/cc100-start <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec java -jar /opt/cc100/target/cc100-0.0.1-SNAPSHOT.jar
EOF
chmod +x /usr/local/bin/cc100-start
