# server to avoid http.server caching files
import http.server
import socketserver
import os
from http.server import SimpleHTTPRequestHandler

class NoCacheHTTPRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

# Change to the build/web directory
os.chdir('build/web')

PORT = 8000
with socketserver.TCPServer(("", PORT), NoCacheHTTPRequestHandler) as httpd:
    print(f"Server running at http://localhost:{PORT}")
    print(f"Serving files from: {os.getcwd()}")
    httpd.serve_forever()