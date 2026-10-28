#!/usr/bin/env bash
set -euo pipefail
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3 ca-certificates curl
rm -rf /var/lib/apt/lists/*
cat > /usr/local/bin/jenkins-backend.py <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/jenkins':
            body = b'Jenkins proxy is healthy\n'
            self.send_response(200)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)
    def log_message(self, *_args):
        pass

HTTPServer(('127.0.0.1', 8081), Handler).serve_forever()
PY
chmod 755 /usr/local/bin/jenkins-backend.py
