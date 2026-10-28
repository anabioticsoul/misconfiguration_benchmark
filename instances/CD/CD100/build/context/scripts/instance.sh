#!/usr/bin/env bash
set -euo pipefail

cat > /root/.config/Code/User/settings.json <<'EOF'
{
  "editor.tabSize": 4,
  "editor.insertSpaces": true
}
EOF
