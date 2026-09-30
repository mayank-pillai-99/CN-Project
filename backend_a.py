from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json

BACKEND_ID = 'A'
PORT = 3001

# /api/cacheable has an IDENTICAL body on A and B, so the ETag is the same on
# both. A conditional request still gets a 304 even if nginx sends it to the
# other backend.
CACHEABLE_BODY = json.dumps({"resource": "cacheable", "version": 1}, sort_keys=True).encode('utf-8')
CACHEABLE_ETAG = '"%s"' % hashlib.sha256(CACHEABLE_BODY).hexdigest()[:16]


class BackendAHandler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def _send(self, code, body=b'', ctype='application/json', extra=None):
        self.send_response(code)
        # Mandatory header (Task C): shows which backend served the response
        self.send_header('X-Backend', BACKEND_ID)
        if code != 304:
            self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', '0' if code == 304 else str(len(body)))
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self.end_headers()
        if self.command != 'HEAD' and code != 304:
            self.wfile.write(body)

    def do_GET(self):
        path = self.path.split('?', 1)[0]

        if path == '/':
            body = b"<h1>Hello from Backend A!</h1><p>Service is running.</p>"
            self._send(200, body, 'text/html', {'Cache-Control': 'no-cache'})
        elif path == '/api/status':
            body = json.dumps({"backend": BACKEND_ID, "status": "ok"}).encode('utf-8')
            self._send(200, body, extra={'Cache-Control': 'max-age=60'})
        elif path == '/api/cacheable':
            # TASK F: Cache-Control + ETag + conditional request (304)
            headers = {'Cache-Control': 'max-age=60', 'ETag': CACHEABLE_ETAG}
            if self.headers.get('If-None-Match', '').strip() == CACHEABLE_ETAG:
                self._send(304, extra=headers)
            else:
                self._send(200, CACHEABLE_BODY, extra=headers)
        else:
            self._send(404, json.dumps({"error": "not found"}).encode('utf-8'))

    do_HEAD = do_GET


if __name__ == '__main__':
    # Listen on all interfaces (0.0.0.0) so other Macs can reach it
    server_address = ('0.0.0.0', PORT)
    httpd = ThreadingHTTPServer(server_address, BackendAHandler)
    print("Backend %s running on port %d..." % (BACKEND_ID, PORT))
    print("Press Ctrl+C to stop.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
