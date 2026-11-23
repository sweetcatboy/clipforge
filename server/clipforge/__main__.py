"""ClipForge command line.

  python -m clipforge serve [--port 7313] [--public]     run the bot server (Studio's Bot Link connects to it)
  python -m clipforge mcp                                MCP server for AI bots (stdio)
  python -m clipforge make <link-or-file> [--kind both] [--start 3 --end 9] [--name Dance]
  python -m clipforge make --prompt "huge purple lightning slash"
  python -m clipforge token                              print the token bots on other machines must send
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.request

from . import config


def _server_up():
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{config.DEFAULT_PORT}/api/health", timeout=1.5) as r:
            return json.loads(r.read().decode()).get("name") == "ClipForge"
    except Exception:
        return False


def cmd_make(a):
    payload = {"kind": a.kind, "client": "cli", "name": a.name, "options": {}}
    if a.prompt:
        payload["prompt"] = a.prompt
        if not a.source:
            payload["kind"] = "vfx"
    if a.source:
        payload["source"] = a.source
    for k in ("start", "end", "style", "rootMotion"):
        v = getattr(a, k.lower() if k != "rootMotion" else "root_motion", None)
        if v is not None:
            payload["options"][k] = v
    if a.loop:
        payload["options"]["loop"] = True
    if a.mirror:
        payload["options"]["mirror"] = True

    if _server_up():
        from .mcp_server import HttpBackend
        be = HttpBackend(f"http://127.0.0.1:{config.DEFAULT_PORT}")
        job = be.create(payload)
        print(f"Queued job {job['id']} on the running bot server; waiting...")
        last = None
        while True:
            job = be.get(job["id"], wait=2)
            line = f"  {job['status']:<11} {int((job.get('progress') or 0) * 100):3d}%  {job.get('message') or ''}"
            if line != last:
                print(line)
                last = line
            if job["status"] in ("done", "failed", "cancelled"):
                break
    else:
        from .jobs import JobStore
        store = JobStore()
        j = store.create(payload)
        print(f"Bot server not running: processing job {j.id} here...")
        last = None
        while True:
            job = store.wait_for(j.id, 2).to_dict()
            line = f"  {job['status']:<11} {int((job.get('progress') or 0) * 100):3d}%  {job.get('message') or ''}"
            if line != last:
                print(line)
                last = line
            if job["status"] in ("done", "failed", "cancelled"):
                break
        time.sleep(0.1)
    if job["status"] != "done":
        print("FAILED:", job.get("error"))
        return 1
    print(json.dumps(job.get("summary"), indent=1))
    print(f"Result: {config.JOBS_DIR}\\{job['id']}\\result.json  (Studio builds it via Bot Link)")
    return 0


def main(argv=None):
    p = argparse.ArgumentParser(prog="clipforge", description="Video -> Roblox animation & VFX")
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("serve")
    s.add_argument("--host", default=config.DEFAULT_HOST)
    s.add_argument("--port", type=int, default=config.DEFAULT_PORT)
    s.add_argument("--public", action="store_true", help="listen on all interfaces (bots need the token)")
    sub.add_parser("mcp")
    sub.add_parser("token")
    m = sub.add_parser("make")
    m.add_argument("source", nargs="?")
    m.add_argument("--prompt")
    m.add_argument("--kind", default="both", choices=["animation", "vfx", "both"])
    m.add_argument("--name")
    m.add_argument("--start", type=float)
    m.add_argument("--end", type=float)
    m.add_argument("--style")
    m.add_argument("--root-motion", dest="root_motion", choices=["inplace", "full", "none"])
    m.add_argument("--loop", action="store_true")
    m.add_argument("--mirror", action="store_true")
    a = p.parse_args(argv)
    if a.cmd == "serve":
        from .server import serve
        serve(a.host, a.port, a.public)
        return 0
    if a.cmd == "mcp":
        from .mcp_server import run
        run()
        return 0
    if a.cmd == "token":
        print(config.bot_token())
        return 0
    if a.cmd == "make":
        if not a.source and not a.prompt:
            p.error("give a link/file or --prompt")
        return cmd_make(a)
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
