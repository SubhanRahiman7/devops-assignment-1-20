"""Tiny HTTP API around the calculator (standard library only).

GET /health                     -> {"status": "ok"}
GET /calc?op=add&a=10&b=5       -> {"op": "add", "a": 10.0, "b": 5.0, "result": 15.0}
"""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

from app.calculator import add, divide, multiply, subtract

OPS = {"add": add, "subtract": subtract, "multiply": multiply, "divide": divide}
VERSION = os.getenv("APP_VERSION", "dev")


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/health":
            return self._send(200, {"status": "ok", "version": VERSION})
        if url.path == "/calc":
            q = parse_qs(url.query)
            try:
                op = q["op"][0]
                a, b = float(q["a"][0]), float(q["b"][0])
                if op not in OPS:
                    return self._send(400, {"error": f"unknown op '{op}'"})
                return self._send(200, {"op": op, "a": a, "b": b, "result": OPS[op](a, b)})
            except (KeyError, ValueError) as exc:
                return self._send(400, {"error": str(exc) or "invalid parameters"})
        return self._send(404, {"error": "not found"})

    def log_message(self, fmt, *args):  # keep container logs quiet
        pass


def make_server(port=8000):
    return HTTPServer(("0.0.0.0", port), Handler)


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    print(f"Calculator API listening on :{port}", flush=True)
    make_server(port).serve_forever()
