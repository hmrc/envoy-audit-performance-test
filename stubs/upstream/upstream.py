from http.server import BaseHTTPRequestHandler, HTTPServer
import json


class UpstreamHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        self.rfile.read(length)
        self._respond(200, json.dumps({"status": "ok"}).encode())

    def do_GET(self):
        self._respond(200, json.dumps({"resource": "data"}).encode())

    def _respond(self, status: int, body: bytes):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 9090), UpstreamHandler)
    print("Upstream stub listening on :9090")
    server.serve_forever()
