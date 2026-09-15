#!/usr/bin/env python3
"""Internal webhook to trigger Uptime Kuma monitor sync (CT153)."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HOST = os.environ.get("UK_SYNC_HOST", "0.0.0.0")
PORT = int(os.environ.get("UK_SYNC_PORT", "18771"))
TOKEN_FILE = Path(os.environ.get("UK_SYNC_TOKEN_FILE", "/opt/uptime-kuma-app/.sync-token"))
SCRIPT = Path(os.environ.get("UK_SYNC_SCRIPT", "/opt/uptime-kuma-app/sync-uptime-kuma-monitors.sh"))


def load_token() -> str:
    if not TOKEN_FILE.is_file():
        raise RuntimeError(f"missing token file: {TOKEN_FILE}")
    return TOKEN_FILE.read_text().strip()


class SyncHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("[sync-webhook] " + (fmt % args) + "\n")

    def _auth_ok(self) -> bool:
        return self.headers.get("X-Sync-Token", "") == load_token()

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path.rstrip("/") == "/health":
            self._json(200, {"ok": True})
            return
        self._json(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path.rstrip("/") != "/sync":
            self._json(404, {"error": "not found"})
            return
        if not self._auth_ok():
            self._json(401, {"error": "unauthorized"})
            return
        if not SCRIPT.is_file():
            self._json(500, {"error": f"sync script missing: {SCRIPT}"})
            return
        proc = subprocess.run(
            [str(SCRIPT)],
            capture_output=True,
            text=True,
            check=False,
        )
        ok = proc.returncode == 0
        self._json(
            200 if ok else 500,
            {
                "ok": ok,
                "returncode": proc.returncode,
                "stdout": proc.stdout,
                "stderr": proc.stderr,
            },
        )


def main() -> None:
    load_token()
    server = HTTPServer((HOST, PORT), SyncHandler)
    sys.stderr.write(f"[sync-webhook] listening on {HOST}:{PORT}\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
