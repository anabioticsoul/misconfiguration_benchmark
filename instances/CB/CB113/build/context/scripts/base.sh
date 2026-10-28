#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends openjdk-11-jre-headless ca-certificates
rm -rf /var/lib/apt/lists/*
install -d /usr/local/bin
cat > /usr/local/bin/java-home-check <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${JAVA_HOME:-}" || ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "JAVA_HOME does not contain a usable Java installation" >&2
  exit 1
fi
exec "$JAVA_HOME/bin/java" -version
EOF
chmod 0755 /usr/local/bin/java-home-check
