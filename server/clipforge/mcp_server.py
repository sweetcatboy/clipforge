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
        "name": "clipforge_make",
        "description": "Make whatever a message asks for in Roblox, no video needed: an animation from a library of "
                       "hand-keyed moves (punches, kicks, sword slashes, thrusts, overhead slams, spins, casts, beams, "
                       "jumps, flips, rolls, dashes, runs, reactions, emotes, combos), an effect from a 100-effect "
                       "library, both linked as an ability (the effect fires on the animation's Hit frame with hit-stop "
                       "and camera shake), a generated showcase effect, a weapon/prop model or a cutscene. Send the "
                       "words as people typed them: 'fire punch', 'make me a backflip', 'kamehameha', 'jab then cross "
                       "then uppercut', 'huge purple lightning slash', 'glowing katana', 'boss intro cutscene'. Studio "
                       "builds the result. Set preview to see what it would make without making it.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {"type": "string", "description": "The request, in the user's own words"},
                "kind": {"type": "string", "enum": ["auto", "animation", "vfx", "both", "generate", "cutscene", "model"],
                         "default": "auto", "description": "auto reads the words; force one to override"},
                "name": {"type": "string"},
                "speed": {"type": "number", "description": "Animation speed (1 = normal)"},
                "loop": {"type": "boolean"},
                "mirror": {"type": "boolean", "description": "Left-handed / mirrored animation"},
                "preview": {"type": "boolean", "default": False},
            },
            "required": ["message"],
        },
    },
    {
        "name": "clipforge_animation_from_prompt",
        "description": "Make a Roblox animation from words, baked onto any R15 or R6 rig in Studio, with a Hit marker "
                       "on contact frames: 'uppercut', 'heavy overhead slam', 'fast sword slash', 'slow wave', "
                       "'dodge roll', 'jab then cross then hook', 'left hook', 'looping idle'. Speed and power words "
                       "(fast, slow, heavy, huge) and left/mirror are understood. Set effect to also make the move's "
                       "effect and link both as an ability. clipforge_presets lists every move.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string"},
                "effect": {"type": "boolean", "default": False, "description": "Also make the matching effect + ability"},
                "speed": {"type": "number"},
                "loop": {"type": "boolean"},
                "mirror": {"type": "boolean"},
                "name": {"type": "string"},
            },
            "required": ["prompt"],
        },
    },
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
        "description": "Make a professional Roblox VFX effect from a description, picked from a 100-effect library "
                       "(slashes, impacts, elements, magic, movement, game feel such as coin bursts, egg hatches and "
                       "loot beams, ambient loops) and recoloured to the words: 'huge purple lightning slash', 'small "
                       "holy heal', 'fast red fireball that explodes', 'ice slam', 'chain lightning', 'level up', "
                       "'falling leaves'. Studio builds it.",
        "inputSchema": {
            "type": "object",
            "properties": {"prompt": {"type": "string"}, "name": {"type": "string"}},
            "required": ["prompt"],
        },
    },
    {
        "name": "clipforge_generate_vfx",
        "description": "Generate a showcase-grade composed VFX from a description: a hero shape (glowing cube, "
                       "wireframe cube, crystal, orb) with frames (orbit rings, wings, heart, halo, rune circle), "
                       "energy (light shafts, rays, lightning arcs, swirl) and atmosphere (nebula, stars, floating "
                       "squares, petals, leaves, smoke, embers), or an impact or a black-hole vortex, with "
                       "optional chromatic RGB-split fringes. E.g. 'golden glowing cube with light wings', 'galaxy "
                       "wireframe cube with orbit rings', 'blue black hole with floating rocks', 'white chromatic "
                       "impact'. Studio builds and saves it as an effect.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string"},
                "mode": {"type": "string", "enum": ["auto", "showcase", "impact", "vortex"], "default": "auto"},
                "chromatic": {"type": "boolean", "description": "Force rainbow fringes on/off (default: from words)"},
                "seed": {"type": "integer", "description": "Another variation of the same idea", "default": 1},
                "name": {"type": "string"},
            },
            "required": ["prompt"],
        },
    },
    {
        "name": "clipforge_make_cutscene",
        "description": "Make a Roblox cutscene (camera shots, letterbox, dialogue, titles, VFX, shake, fades). From a "
                       "prompt it uses a template (boss intro, victory, dramatic reveal, ability showcase, map "
                       "flyover, dialogue, defeat); quoted text becomes dialogue: 'boss intro \"You dare challenge "
                       "me?\"'. From a video link it copies the clip's cuts and camera moves (push in, orbit, tilt, "
                       "locked off), shot sizes, shake, flashes and fades onto your character. Shots film the "
                       "actor named `who` (default Target): play with "
                       "require(ReplicatedStorage.ClipForge.Cutscene).play(name, {actors = {Target = model}}).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string", "description": "What happens; quoted text becomes lines"},
                "source": {"type": "string", "description": "Optional video link/file to copy the camera work from"},
                "who": {"type": "string", "default": "Target"},
                "template": {"type": "string", "enum": ["intro", "victory", "reveal", "ability", "flyover",
                                                        "dialogue", "defeat"]},
                "title": {"type": "string"},
                "effect": {"type": "string", "description": "Library effect id to fire (e.g. shockwave)"},
                "start": {"type": "number"}, "end": {"type": "number"},
                "name": {"type": "string"},
                "timeout": {"type": "number", "default": 240},
            },
        },
    },
    {
        "name": "clipforge_make_model",
        "description": "Make a Roblox weapon or prop model from a description: sword, katana, greatsword, dagger, "
                       "axe, spear, staff, wand, scythe, hammer, shield, magic orb, crystal cluster, rock, meteor, "
                       "portal, rune totem; styles steel, dark, gold, crystal, energy, wood; optional glow colour. "
                       "E.g. 'glowing purple katana', 'golden greatsword', 'crystal staff'. Studio builds it in "
                       "the workspace, ready to attach to a rig or turn into a Tool.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string"},
                "style": {"type": "string", "enum": ["steel", "dark", "gold", "crystal", "energy", "wood"]},
                "glow": {"type": "string", "description": "#RRGGBB"},
                "scale": {"type": "number"},
                "name": {"type": "string"},
            },
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
        "description": "Everything ClipForge can build: library effects (id, title, category), generator options, "
                       "cutscene templates, model types and the animation moves.",
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
        return self._req("GET", "/api/catalog")

    def preview(self, payload):
        return self._req("POST", "/api/preview", payload)


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
        from .catalog import summary
        return summary()

    def preview(self, payload):
        return self.store.preview(payload)


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
    if job.get("buildError") and not job.get("delivered"):
        out["buildError"] = job["buildError"]
        out["next"] = ("Studio could not build it: " + job["buildError"] + ". Update the ClipForge plugin, then press "
                       "Build here on the job in the plugin's Bots tab.")
        return out
    if job.get("status") == "done":
        out["next"] = ("Built in Roblox Studio." if job.get("delivered") else
                       "Ready: Roblox Studio builds it when the ClipForge plugin's Bot Link is on "
                       "(ServerStorage.ClipForge.Animations for animations, ReplicatedStorage.ClipForge.Effects for "
                       "VFX, ReplicatedStorage.ClipForge.Cutscenes for cutscenes, the workspace for models).")
    return out


def _anim_opts(args):
    return {k: args[k] for k in ("speed", "loop", "mirror") if args.get(k) is not None}


def _call(backend, name, args):
    if name == "clipforge_make":
        payload = {"prompt": args["message"], "kind": args.get("kind") or "auto", "name": args.get("name"),
                   "options": _anim_opts(args), "client": "mcp"}
        if args.get("preview"):
            pv = backend.preview(payload)
            plan = pv["plan"]
            return {"would_make": pv.get("message"), "plan": {k: v for k, v in plan.items() if v}}
        return _summary(backend.get(backend.create(payload)["id"], wait=30))
    if name == "clipforge_animation_from_prompt":
        job = backend.create({"prompt": args["prompt"], "kind": "both" if args.get("effect") else "animation",
                              "name": args.get("name"), "options": _anim_opts(args), "client": "mcp"})
        return _summary(backend.get(job["id"], wait=30))
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
    if name == "clipforge_generate_vfx":
        opts = {k: args[k] for k in ("seed", "chromatic") if k in args}
        if args.get("mode") and args["mode"] != "auto":
            opts["mode"] = args["mode"]
        job = backend.create({"prompt": args["prompt"], "kind": "generate", "name": args.get("name"),
                              "options": opts, "client": "mcp"})
        return _summary(backend.get(job["id"], wait=30))
    if name == "clipforge_make_cutscene":
        if not args.get("prompt") and not args.get("source"):
            raise ValueError("Give a prompt (what happens) or a source video to copy the camera work from.")
        opts = {k: args[k] for k in ("who", "template", "title", "effect", "start", "end") if args.get(k) is not None}
        job = backend.create({"prompt": args.get("prompt"), "source": args.get("source"), "kind": "cutscene",
                              "name": args.get("name"), "options": opts, "client": "mcp"})
        return _summary(backend.get(job["id"], wait=float(args.get("timeout", 240)) if args.get("source") else 30))
    if name == "clipforge_make_model":
        opts = {k: args[k] for k in ("style", "glow", "scale") if args.get(k) is not None}
        job = backend.create({"prompt": args["prompt"], "kind": "model", "name": args.get("name"), "options": opts,
                              "client": "mcp"})
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
        line = line.strip().lstrip(chr(0xFEFF)).strip()  # some shells start the stream with a byte-order mark
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            out.write(json.dumps({"jsonrpc": "2.0", "id": None,
                                  "error": {"code": -32700, "message": "Parse error: send one JSON-RPC message per line"}}) + "\n")
            out.flush()
            continue
        if not isinstance(msg, dict):
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
                          "instructions": "Make Roblox animations, VFX, generated showcase VFX, cutscenes and "
                                          "weapon/prop models from social-media videos or from words. For a request "
                                          "in plain words use clipforge_make with the message as typed. Studio "
                                          "builds results via the ClipForge plugin's Bot Link."}
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
