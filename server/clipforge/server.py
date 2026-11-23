"""ClipForge bot server: a small local REST API. Bots (Discord bots, scripts, AI agents) and the Studio plugin talk
to it. Bound to 127.0.0.1 by default; bots on other machines need --public and the bot token."""
from __future__ import annotations

import hmac
import ipaddress
import json
import mimetypes
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from . import config
from .jobs import JobStore
from .vfx_analyze import ARCHETYPES

STORE: JobStore | None = None


def presets():
    return [{"base": base, "archetype": arch, "description": desc} for arch, (base, _, desc) in ARCHETYPES.items()]


OPENAPI = {
    "openapi": "3.0.3",
    "info": {"title": "ClipForge bot API", "version": config.VERSION,
             "description": "Turn social-media clips (YouTube, TikTok, Instagram, X...) or text prompts into Roblox "
                            "animations and VFX. Finished jobs are built in Roblox Studio by the ClipForge plugin."},
    "paths": {
        "/api/jobs": {
            "post": {"summary": "Create a job", "requestBody": {"content": {"application/json": {"schema": {
                "type": "object",
                "properties": {
                    "source": {"type": "string", "description": "Video link or a local file path"},
                    "kind": {"type": "string", "enum": ["animation", "vfx", "both"]},
                    "prompt": {"type": "string", "description": "Describe an effect (no video needed for VFX)"},
                    "name": {"type": "string"},
                    "client": {"type": "string", "description": "Who is asking, e.g. 'discord-bot'"},
                    "options": {"type": "object", "properties": {
                        "start": {"type": "number"}, "end": {"type": "number"},
                        "rootMotion": {"type": "string", "enum": ["inplace", "full", "none"]},
                        "loop": {"type": "boolean"}, "mirror": {"type": "boolean"},
                        "smoothing": {"type": "number", "minimum": 0, "maximum": 1},
                        "lockFacing": {"type": "boolean"}, "speed": {"type": "number"},
                        "style": {"type": "string", "enum": ["auto"] + list(ARCHETYPES)},
                        "scale": {"type": "number"}}}}}}}}},
            "get": {"summary": "List jobs (?since=seq&status=done&undelivered=1)"}},
        "/api/jobs/{id}": {"get": {"summary": "Job status (?wait=seconds long-polls until it finishes)"},
                           "delete": {"summary": "Cancel/delete a job"}},
        "/api/jobs/{id}/result": {"get": {"summary": "Full animation/VFX data"}},
        "/api/jobs/{id}/delivered": {"post": {"summary": "Mark as built in Studio (the plugin calls this)"}},
        "/api/presets": {"get": {"summary": "Base effect recipes"}},
        "/api/health": {"get": {"summary": "Server status"}},
    },
}

LANDING = """<!DOCTYPE html><html><head><meta charset="utf-8"><title>ClipForge bot server</title>
<style>body{font:15px/1.5 system-ui,Segoe UI,sans-serif;background:#0f1117;color:#e6e8ef;margin:0}
main{max-width:860px;margin:40px auto;padding:0 20px}h1{font-size:26px;margin:0 0 4px}
.sub{color:#9aa3b5;margin-bottom:24px}.card{background:#171a23;border:1px solid #262b38;border-radius:12px;padding:18px;margin:14px 0}
input,select{background:#0f1117;color:#e6e8ef;border:1px solid #2d3343;border-radius:8px;padding:9px 11px;font:inherit}
input[type=text]{width:100%;box-sizing:border-box}button{background:#7c5cff;color:#fff;border:0;border-radius:8px;padding:9px 16px;font:inherit;cursor:pointer}
code{background:#0f1117;border:1px solid #262b38;border-radius:6px;padding:1px 6px}table{width:100%;border-collapse:collapse}
td{padding:6px 4px;border-top:1px solid #262b38;font-size:13px;vertical-align:top}.ok{color:#5be49b}.bad{color:#ff6b6b}
.row{display:flex;gap:10px;margin-top:10px;align-items:center;flex-wrap:wrap}</style></head><body><main>
<h1>ClipForge bot server</h1><div class="sub">Video &rarr; Roblox animation &amp; VFX. Running v__VERSION__ on port __PORT__.</div>
<div class="card"><b>Make something</b><input id="src" type="text" placeholder="Paste a YouTube / TikTok / Instagram / X link, or describe an effect">
<div class="row"><select id="kind"><option value="both">Animation + VFX</option><option value="animation">Animation</option>
<option value="vfx">VFX</option></select><input id="start" placeholder="start s" size="6"><input id="end" placeholder="end s" size="6">
<button onclick="go()">Generate</button><span id="msg"></span></div></div>
<div class="card"><b>Recent jobs</b><table id="jobs"></table></div>
<div class="card"><b>For bots</b><br><code>POST /api/jobs {"source": "&lt;link&gt;", "kind": "both"}</code> &rarr; poll
<code>GET /api/jobs/&lt;id&gt;?wait=60</code>. Text effects: <code>{"prompt": "huge purple lightning slash"}</code>.
Spec: <a style="color:#a996ff" href="/openapi.json">/openapi.json</a>. Bots on other machines send
<code>Authorization: Bearer &lt;token&gt;</code> (token in <code>server/data/bot_token.txt</code>).</div>
<script>
async function go(){const s=document.getElementById('src').value.trim();if(!s)return;
const isUrl=/^https?:\\/\\//i.test(s)||/^[a-z]:\\\\/i.test(s);const body={kind:document.getElementById('kind').value,client:'web',options:{}};
if(isUrl)body.source=s;else{body.prompt=s;body.kind='vfx'}
const st=document.getElementById('start').value,en=document.getElementById('end').value;if(st)body.options.start=+st;if(en)body.options.end=+en;
const r=await fetch('/api/jobs',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
const j=await r.json();document.getElementById('msg').textContent=r.ok?('queued '+j.id):(j.error||'error');load()}
async function load(){const r=await fetch('/api/jobs?limit=15');const j=await r.json();
document.getElementById('jobs').innerHTML=j.jobs.map(x=>`<tr><td>${x.name||x.id}</td><td>${x.kind}</td><td class="${x.status=='failed'?'bad':(x.status=='done'?'ok':'')}">${x.status} ${x.status=='done'||x.status=='failed'?'':Math.round(x.progress*100)+'%'}</td><td>${(x.error||x.message||'').replace(/</g,'&lt;')}</td><td>${x.delivered?'in Studio':''}</td></tr>`).join('')}
load();setInterval(load,2000);
</script></main></body></html>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "ClipForge/" + config.VERSION
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # quieter console
        if "/api/jobs?" in (args[0] if args else ""):
            return
        super().log_message(fmt, *args)

    # --- helpers --------------------------------------------------------------------------------------------------
    def _send(self, code, obj=None, ctype="application/json", raw: bytes | None = None):
        body = raw if raw is not None else json.dumps(obj, separators=(",", ":")).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype + ("; charset=utf-8" if ctype.startswith(("application/json", "text/")) else ""))
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _err(self, code, msg):
        self._send(code, {"error": msg})

    def _is_local(self):
        try:
            return ipaddress.ip_address(self.client_address[0]).is_loopback
        except ValueError:
            return False

    def _authorised(self):
        if self._is_local():
            return True
        tok = config.bot_token()
        got = self.headers.get("X-ClipForge-Token") or ""
        auth = self.headers.get("Authorization") or ""
        if auth.lower().startswith("bearer "):
            got = auth[7:].strip()
        return bool(got) and hmac.compare_digest(got, tok)

    def _origin_ok(self):
        """Block other websites from driving the API through the user's browser."""
        origin = self.headers.get("Origin")
        if not origin:
            return True
        port = self.server.server_address[1]
        return origin in (f"http://127.0.0.1:{port}", f"http://localhost:{port}")

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > 2_000_000:
            raise ValueError("Request too large")
        raw = self.rfile.read(n) if n else b""
        if not raw:
            return {}
        ctype = (self.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        if ctype != "application/json":
            raise ValueError("Send JSON with Content-Type: application/json")
        return json.loads(raw.decode("utf-8"))

    def _route(self):
        u = urlparse(self.path)
        parts = [p for p in u.path.split("/") if p]
        return parts, {k: v[-1] for k, v in parse_qs(u.query).items()}

    # --- verbs ----------------------------------------------------------------------------------------------------
    def do_GET(self):
        parts, q = self._route()
        if not parts:
            page = LANDING.replace("__VERSION__", config.VERSION).replace("__PORT__", str(self.server.server_address[1]))
            return self._send(200, raw=page.encode("utf-8"), ctype="text/html")
        if not self._authorised():
            return self._err(401, "Bot token required (Authorization: Bearer <token>).")
        if parts == ["openapi.json"]:
            return self._send(200, OPENAPI)
        if parts[0] != "api":
            return self._err(404, "Not found")
        if parts[1:] == ["health"]:
            active = len([j for j in STORE.list(limit=10000) if j["status"] not in ("done", "failed", "cancelled")])
            return self._send(200, {"ok": True, "name": "ClipForge", "version": config.VERSION, "active": active})
        if parts[1:] == ["presets"]:
            return self._send(200, {"presets": presets()})
        if parts[1:2] == ["jobs"]:
            if len(parts) == 2:
                jobs = STORE.list(since=int(q.get("since") or 0), status=q.get("status"),
                                  undelivered=q.get("undelivered") in ("1", "true"), limit=int(q.get("limit") or 50))
                return self._send(200, {"jobs": jobs, "seq": STORE.seq})
            job = STORE.get(parts[2])
            if not job:
                return self._err(404, "No such job")
            if len(parts) == 3:
                wait = min(float(q.get("wait") or 0), 300.0)
                if wait > 0:
                    job = STORE.wait_for(job.id, wait) or job
                return self._send(200, job.to_dict())
            if parts[3] == "result":
                res = STORE.result(job.id)
                return self._send(200, res) if res else self._err(409, f"Job is {job.status}")
            if parts[3] == "files" and len(parts) == 5:
                p = STORE.file_path(job.id, parts[4])
                if not p:
                    return self._err(404, "No such file")
                with open(p, "rb") as f:
                    data = f.read()
                return self._send(200, raw=data, ctype=mimetypes.guess_type(p)[0] or "application/octet-stream")
        return self._err(404, "Not found")

    def do_POST(self):
        parts, _ = self._route()
        if not self._authorised():
            return self._err(401, "Bot token required (Authorization: Bearer <token>).")
        if not self._origin_ok():
            return self._err(403, "Cross-site requests are not allowed.")
        try:
            body = self._body()
        except ValueError as e:
            return self._err(400, str(e))
        except json.JSONDecodeError:
            return self._err(400, "Body is not valid JSON")
        if parts == ["api", "jobs"]:
            try:
                job = STORE.create(body)
            except ValueError as e:
                return self._err(400, str(e))
            return self._send(201, job.to_dict())
        if len(parts) == 4 and parts[:2] == ["api", "jobs"] and parts[3] == "claim":
            ok, job = STORE.claim(parts[2], str(body.get("studio") or "studio"), bool(body.get("release")))
            if job is None:
                return self._err(404, "No such job")
            return self._send(200, job.to_dict()) if ok else self._err(409, "Already taken by " + str(job.claimedBy))
        if len(parts) == 4 and parts[:2] == ["api", "jobs"] and parts[3] == "delivered":
            job = STORE.mark_delivered(parts[2], body)
            return self._send(200, job.to_dict()) if job else self._err(404, "No such job")
        return self._err(404, "Not found")

    def do_DELETE(self):
        parts, _ = self._route()
        if not self._authorised():
            return self._err(401, "Bot token required.")
        if not self._origin_ok():
            return self._err(403, "Cross-site requests are not allowed.")
        if len(parts) == 3 and parts[:2] == ["api", "jobs"]:
            return self._send(200, {"deleted": STORE.delete(parts[2])})
        return self._err(404, "Not found")


def make_server(host: str = config.DEFAULT_HOST, port: int = config.DEFAULT_PORT, store: JobStore | None = None):
    global STORE
    STORE = store or STORE or JobStore()
    httpd = ThreadingHTTPServer((host, port), Handler)
    httpd.daemon_threads = True
    return httpd


def serve(host: str = config.DEFAULT_HOST, port: int = config.DEFAULT_PORT, public: bool = False):
    if public and host == config.DEFAULT_HOST:
        host = "0.0.0.0"
    httpd = make_server(host, port)
    tok = config.bot_token()
    print(f"ClipForge bot server v{config.VERSION} on http://{'127.0.0.1' if host in ('127.0.0.1', '0.0.0.0') else host}:{port}")
    if host != "127.0.0.1":
        print(f"  Listening on {host}: bots on other machines must send  Authorization: Bearer {tok}")
    print("  In Studio: ClipForge > Bot Link > Connect.  Ctrl+C to stop.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


def serve_in_thread(host: str = config.DEFAULT_HOST, port: int = config.DEFAULT_PORT, store: JobStore | None = None):
    httpd = make_server(host, port, store)
    t = threading.Thread(target=httpd.serve_forever, name="clipforge-http", daemon=True)
    t.start()
    return httpd
