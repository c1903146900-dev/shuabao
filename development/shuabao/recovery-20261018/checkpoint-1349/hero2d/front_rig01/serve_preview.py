"""Local-only five-file preview. No game process, directory listing or public bind."""
import argparse
import hashlib
import http.server
import json
from pathlib import Path
import time

FILES = {
    '/preview.html': ('preview.html', 'text/html; charset=utf-8'),
    '/rig.js': ('rig.js', 'text/javascript; charset=utf-8'),
    '/neutral_parts_original.png': ('neutral_parts_original.png', 'image/png'),
    '/upper_q1_eight_original.png': ('upper_q1_eight_original.png', 'image/png'),
    '/lower_idle_walk_nine_original.png': ('lower_idle_walk_nine_original.png', 'image/png'),
}
ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--status', required=True, help='Fresh absolute JSON output path')
parser.add_argument('--stop', required=True, help='Initially absent absolute stop-file path')
parser.add_argument('--ttl', type=float, default=180)
args = parser.parse_args()
status = Path(args.status)
stop = Path(args.stop)
if not status.is_absolute() or not stop.is_absolute() or status.exists() or stop.exists():
    raise SystemExit('Status and stop must be fresh absolute paths')
if not (1 <= args.ttl <= 180):
    raise SystemExit('TTL must be between 1 and 180 seconds')
if not status.parent.is_dir() or not stop.parent.is_dir():
    raise SystemExit('Output parents must already exist')
files = []
for name, _ in FILES.values():
    path = ROOT / name
    if path.is_symlink() or not path.is_file() or path.resolve().parent != ROOT:
        raise SystemExit('Unsafe or missing preview file: ' + name)
    data = path.read_bytes()
    files.append({'path': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
requests = []
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.serve(False)
    def do_HEAD(self):
        self.serve(True)
    def log_message(self, *_):
        pass
    def serve(self, head):
        spec = FILES.get(self.path)
        if not spec:
            self.send_error(404)
            return
        path = ROOT / spec[0]
        if path.is_symlink() or not path.is_file() or path.resolve().parent != ROOT:
            self.send_error(409)
            return
        data = path.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', spec[1])
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        if not head:
            self.wfile.write(data)
        if len(requests) < 100:
            requests.append({'path': self.path, 'bytes': len(data)})
class LocalServer(http.server.HTTPServer):
    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(2.0)
        return connection, address
server = LocalServer(('127.0.0.1', 0), Handler)
server.timeout = .2
started = time.monotonic()
report = {'status': 'serving', 'url': f'http://127.0.0.1:{server.server_port}/preview.html',
          'bind': '127.0.0.1', 'ttl_seconds': args.ttl, 'files': files}
with status.open('x', encoding='utf8') as handle:
    json.dump(report, handle, indent=2)
print(json.dumps(report), flush=True)
try:
    while time.monotonic() - started < args.ttl and not stop.exists():
        server.handle_request()
finally:
    server.server_close()
    report.update(status='stopped', elapsed_seconds=time.monotonic()-started,
                  stop_requested=stop.exists(), requests=requests)
    status.write_text(json.dumps(report, indent=2)+'\n', encoding='utf8')
    print(json.dumps({'status': 'stopped', 'requests': len(requests)}), flush=True)
