#!/usr/bin/env python3
import http.server
import ssl

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"upstream HTTPS content\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *_):
        pass

server = http.server.HTTPServer(("127.0.0.1", 8443), Handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain("/etc/nginx/upstream.crt", "/etc/nginx/upstream.key")
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
