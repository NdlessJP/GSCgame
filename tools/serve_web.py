#!/usr/bin/env python3
"""Tiny static server for the web export.

The Godot web build needs two things a plain file server does not give:
the correct MIME type for .wasm (otherwise WebAssembly.instantiateStreaming
refuses the file) and no-cache headers so a rebuild is picked up.

    python3 tools/serve_web.py [port] [directory]
"""

import http.server
import os
import socketserver
import sys

EXTRA_TYPES = {
    ".wasm": "application/wasm",
    ".js": "text/javascript",
    ".mjs": "text/javascript",
    ".pck": "application/octet-stream",
    ".json": "application/json",
    ".svg": "image/svg+xml",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def guess_type(self, path):
        ext = os.path.splitext(path)[1].lower()
        if ext in EXTRA_TYPES:
            return EXTRA_TYPES[ext]
        return super().guess_type(path)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        # Not required for the single threaded build, but harmless and it
        # keeps the door open for a threaded export.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    directory = sys.argv[2] if len(sys.argv) > 2 else "build/web"
    os.chdir(os.path.abspath(directory))
    with Server(("0.0.0.0", port), Handler) as httpd:
        print("serving %s on http://0.0.0.0:%d" % (os.getcwd(), port), flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    main()
