"""MCP server (stdio) so AI bots - Claude, Cursor, other agents - can make Roblox animations and VFX as tools.

If the ClipForge bot server is already running it forwards to it; otherwise it starts one inside this process so
the Studio plugin can still connect and build what the bot makes. Add it to an MCP client as:
    command: <venv>\\Scripts\\python.exe   args: ["-m", "clipforge", "mcp"]   cwd: <ClipForge>\\server
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request

from . import config

PROTOCOL = "2025-06-18"

TOOLS = [
    {
        "name": "clipforge_from_video",
        "description": "Turn a video (YouTube, YouTube Shorts, TikTok, Instagram Reels, X/Twitter, Reddit, Twitch "
                       "clips, or a local file path) into a Roblox animation (body motion retargeted to R15/R6) "
                       "and/or a professional VFX effect in the clip's style. Roblox Studio with the ClipForge "
                       "plugin (Bot Link on) builds the result automatically. Waits for the result by default.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "source": {"type": "string", "description": "Video link or local file path"},
                "kind": {"type": "string", "enum": ["animation", "vfx", "both"], "default": "both"},
                "name": {"type": "string", "description": "Name for the animation/effect in Studio"},
                "start": {"type": "number", "description": "Start time in seconds (optional)"},
                "end": {"type": "number", "description": "End time in seconds (optional)"},
                "rootMotion": {"type": "string", "enum": ["inplace", "full", "none"], "default": "inplace"},
                "loop": {"type": "boolean", "default": False},
                "mirror": {"type": "boolean", "default": False},
                "style": {"type": "string", "description": "Force a VFX type: auto, slash, impact, explosion, "
                          "aura, beam, lightning, projectile, fire, ice, dark, holy", "default": "auto"},
                "wait": {"type": "boolean", "default": True},
                "timeout": {"type": "number", "default": 240},
            },
            "required": ["source"],
        },
    },
    {
        "name": "clipforge_vfx_from_prompt",
        "description": "Make a professional Roblox VFX effect from a description, e.g. 'huge purple lightning "
                       "slash', 'small holy heal burst', 'fast red fireball that explodes'. Studio builds it.",
        "inputSchema": {
            "type": "object",
            "properties": {"prompt": {"type": "string"}, "name": {"type": "string"}},
            "required": ["prompt"],
        },
    },
    {
        "name": "clipforge_job_status",
        "description": "Status of a ClipForge job (optionally wait up to N seconds for it to finish).",
        "inputSchema": {"type": "object", "properties": {"id": {"type": "string"}, "wait": {"type": "number"}},
                        "required": ["id"]},
    },
    {
        "name": "clipforge_list_jobs",
        "description": "Recent ClipForge jobs with their status and whether Studio has built them.",
        "inputSchema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 10}}},
    },
    {
        "name": "clipforge_presets",
        "description": "The base VFX recipes ClipForge builds effects from.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


class HttpBackend:
    def __init__(self, base):
        self.base = base.rstrip("/")

    def _req(self, method, path, body=None, timeout=330):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(self.base + path, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            try:
                msg = json.loads(e.read().decode()).get("error")
            except Exception:
                msg = str(e)
            raise RuntimeError(msg) from e

    def create(self, payload):
        return self._req("POST", "/api/jobs", payload)

    def get(self, job_id, wait=0):
        return self._req("GET", f"/api/jobs/{job_id}" + (f"?wait={wait}" if wait else ""))

    def list(self, limit):
        return self._req("GET", f"/api/jobs?limit={limit}")["jobs"]

    def presets(self):
        return self._req("GET", "/api/presets")["presets"]


class LocalBackend:
    def __init__(self, store):
        self.store = store

    def create(self, payload):
        return self.store.create(payload).to_dict()

    def get(self, job_id, wait=0):
        job = self.store.wait_for(job_id, wait) if wait else self.store.get(job_id)
        if not job:
            raise RuntimeError("No such job")
        return job.to_dict()

    def list(self, limit):
        return self.store.list(limit=limit)

    def presets(self):
        from .server import presets
        return presets()


def _backend():
    base = f"http://127.0.0.1:{config.DEFAULT_PORT}"
    try:
        with urllib.request.urlopen(base + "/api/health", timeout=1.5) as r:
            if json.loads(r.read().decode()).get("name") == "ClipForge":
                return HttpBackend(base), "forwarding to the running bot server"
    except Exception:
        pass
    from .jobs import JobStore
    from .server import serve_in_thread
    store = JobStore()
    try:
        serve_in_thread(config.DEFAULT_HOST, config.DEFAULT_PORT, store)
        note = f"started the bot server on port {config.DEFAULT_PORT}"
    except OSError:
        note = "bot server port busy; jobs run inside the MCP process"
    return LocalBackend(store), note


def _summary(job):
    out = {k: job.get(k) for k in ("id", "status", "progress", "message", "error", "name", "kind", "summary",
                                   "delivered")}
    if job.get("status") == "done":
        out["next"] = ("Built in Roblox Studio." if job.get("delivered") else
                       "Ready: Roblox Studio builds it when the ClipForge plugin's Bot Link is on "
                       "(ServerStorage.ClipForge for animations, ReplicatedStorage.ClipForge.Effects for VFX).")
    return out


def _call(backend, name, args):
    if name == "clipforge_from_video":
        opts = {k: args[k] for k in ("start", "end", "rootMotion", "loop", "mirror", "style") if k in args}
        job = backend.create({"source": args["source"], "kind": args.get("kind", "both"), "name": args.get("name"),
                              "options": opts, "client": "mcp"})
        if args.get("wait", True):
            job = backend.get(job["id"], wait=float(args.get("timeout", 240)))
        return _summary(job)
    if name == "clipforge_vfx_from_prompt":
        job = backend.create({"prompt": args["prompt"], "kind": "vfx", "name": args.get("name"), "client": "mcp"})
        return _summary(backend.get(job["id"], wait=30))
    if name == "clipforge_job_status":
        return _summary(backend.get(args["id"], wait=float(args.get("wait") or 0)))
    if name == "clipforge_list_jobs":
        return [_summary(j) for j in backend.list(int(args.get("limit", 10)))]
    if name == "clipforge_presets":
        return backend.presets()
    raise ValueError(f"Unknown tool {name}")


def run():
    backend, note = _backend()
    print(f"[clipforge-mcp] ready ({note})", file=sys.stderr, flush=True)
    out = sys.stdout
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        mid = msg.get("id")
        method = msg.get("method")
        params = msg.get("params") or {}
        if mid is None:  # notification
            continue
        try:
            if method == "initialize":
                result = {"protocolVersion": params.get("protocolVersion") or PROTOCOL,
                          "capabilities": {"tools": {"listChanged": False}},
                          "serverInfo": {"name": "clipforge", "version": config.VERSION},
                          "instructions": "Make Roblox animations and VFX from social-media videos or prompts. "
                                          "Studio builds results via the ClipForge plugin's Bot Link."}
            elif method == "tools/list":
                result = {"tools": TOOLS}
            elif method == "tools/call":
                try:
                    data = _call(backend, params.get("name"), params.get("arguments") or {})
                    result = {"content": [{"type": "text", "text": json.dumps(data, indent=1)}], "isError": False}
                except Exception as e:
                    result = {"content": [{"type": "text", "text": f"Error: {e}"}], "isError": True}
            elif method == "ping":
                result = {}
            else:
                out.write(json.dumps({"jsonrpc": "2.0", "id": mid,
                                      "error": {"code": -32601, "message": f"Unknown method {method}"}}) + "\n")
                out.flush()
                continue
            out.write(json.dumps({"jsonrpc": "2.0", "id": mid, "result": result}) + "\n")
        except Exception as e:  # pragma: no cover
            out.write(json.dumps({"jsonrpc": "2.0", "id": mid, "error": {"code": -32603, "message": str(e)}}) + "\n")
        out.flush()
