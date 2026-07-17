from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import threading

_count = 0
_lock = threading.Lock()


class StubHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # suppress per-request noise

    def do_POST(self):
        global _count
        if self.path == "/audit/event":
            length = int(self.headers.get("Content-Length", 0))
            self.rfile.read(length)
            with _lock:
                _count += 1
            self._respond(202, b"")
        else:
            self._respond(404, b"")

    def do_GET(self):
        global _count
        if self.path == "/audit/count":
            with _lock:
                body = json.dumps({"count": _count}).encode()
            self._respond(200, body)
        elif self.path == "/audit/reset":
            with _lock:
                _count = 0
            self._respond(200, b"")
        else:
            self._respond(404, b"")

    def _respond(self, status: int, body: bytes):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8080), StubHandler)
    print("CIP Datastream stub listening on :8080")
    server.serve_forever()
