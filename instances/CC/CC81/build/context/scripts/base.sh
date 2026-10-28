#!/usr/bin/env bash
set -euo pipefail
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openjdk-17-jdk ca-certificates
mkdir -p /opt/springboot/classes
javac -d /opt/springboot/classes /opt/springboot/Application.java
cat > /opt/springboot/run.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
options=()
while IFS= read -r option || [ -n "$option" ]; do
    case "$option" in
        ''|'#'*) continue ;;
        *) options+=("$option") ;;
    esac
done < /etc/springboot/java.options
exec java "${options[@]}" -cp /opt/springboot/classes net.guides.springboot2.crud.Application
EOF
chmod +x /opt/springboot/run.sh
rm -rf /var/lib/apt/lists/*
