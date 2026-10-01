from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class BackendAHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # We always return HTTP 200 OK
        self.send_response(200)
        
        # Mandatory headers for the project (Task C and Task F)
        self.send_header('X-Backend', 'A')
        self.send_header('Cache-Control', 'max-age=60')
        
        if self.path == '/api/status':
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {"backend": "A", "status": "ok"}
            self.wfile.write(json.dumps(response).encode('utf-8'))
        else:
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"<h1>Hello from Backend A!</h1><p>Service is running.</p>")

if __name__ == '__main__':
    # Listen on all interfaces (0.0.0.0) so other Macs can reach it, on port 3001
    server_address = ('0.0.0.0', 3001)
    httpd = HTTPServer(server_address, BackendAHandler)
    print("Backend A running on port 3001...")
    print("Press Ctrl+C to stop.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
