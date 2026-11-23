"""Job queue: bots and the Studio plugin submit jobs, a worker turns clips and prompts into animation, VFX, cutscene
and model data, the plugin builds finished jobs in Studio and marks them delivered.

Kinds: animation / vfx / both (from a clip, or from words: text animations come from a library of hand-keyed moves),
generate (a showcase VFX from a description), cutscene (from a clip's cuts and camera moves, or from a prompt via the
plugin's templates), model (a weapon or prop from a description), auto (a free-form message: the router decides)."""
from __future__ import annotations

import json
import os
import queue
import re
import shutil
import threading
import time
import traceback
import uuid

from . import config

KINDS = ("animation", "vfx", "both", "generate", "cutscene", "model", "auto")
DUPLICATE_WINDOW = 5.0  # seconds: the same request again this soon is a double-click
# effects that belong on every hit of a move (a spark per punch); anything else (a black hole, an explosion) is a
# one-off that fires once, on the last hit
PER_HIT_FX = {"punch", "uppercut", "hitspark", "critical", "slash", "thrust", "spinslash", "parry", "landing", "dash",
              "pickup", "slashcombo", "xslash", "impact", "punchbarrage", "claw", "bulletimpact", "muzzleflash"}
NEEDS_PROMPT = ("generate", "model", "auto")
STATUS_ACTIVE = ("queued", "downloading", "tracking", "analyzing", "building")


def _a(phrase: str) -> str:
    """'a slash' / 'an energy beam'."""
    return ("an " if phrase[:1].lower() in "aeiou" else "a ") + phrase


def _now():
    return time.time()


def _safe_name(s: str, fallback: str) -> str:
    words = [w for w in re.split(r"[^A-Za-z0-9]+", s or "") if w]
    name = "".join(w[:1].upper() + w[1:] for w in words)
    if name and name[0].isdigit():
        name = "Clip" + name
    return (name or fallback)[:40]


class Job:
    FIELDS = ("id", "seq", "kind", "source", "prompt", "options", "client", "name", "status", "progress", "message",
              "error", "created", "updated", "delivered", "deliveredInfo", "meta", "hasResult", "summary",
              "claimedBy", "claimedAt", "buildError")

    def __init__(self, **kw):
        for f in self.FIELDS:
            setattr(self, f, kw.get(f))
        self.options = self.options or {}
        self.meta = self.meta or {}
        self.progress = self.progress or 0.0
        self.delivered = bool(self.delivered)
        self.hasResult = bool(self.hasResult)

    def to_dict(self):
        return {f: getattr(self, f) for f in self.FIELDS}


class JobStore:
    def __init__(self, workers: int = 1):
        config.ensure_dirs()
        self.lock = threading.RLock()
        self.jobs: dict[str, Job] = {}
        self.seq = 0
        self.q: queue.Queue[str] = queue.Queue()
        self.changed = threading.Condition(self.lock)
        self.releases: dict[str, list[float]] = {}  # job id -> times a Studio gave it back unbuilt
        self.recent: dict[str, tuple[str, float]] = {}  # request -> (job id, time): double-clicks make one job
        self._load()
        for i in range(max(1, workers)):
            threading.Thread(target=self._worker, name=f"clipforge-worker-{i}", daemon=True).start()

    # --- persistence ----------------------------------------------------------------------------------------------
    def _dir(self, job_id):
        return os.path.join(config.JOBS_DIR, job_id)

    def _save(self, job: Job):
        d = self._dir(job.id)
        os.makedirs(d, exist_ok=True)
        tmp = os.path.join(d, "job.json.tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(job.to_dict(), f, indent=1)
        os.replace(tmp, os.path.join(d, "job.json"))

    def _load(self):
        if not os.path.isdir(config.JOBS_DIR):
            return
        for jid in os.listdir(config.JOBS_DIR):
            p = os.path.join(config.JOBS_DIR, jid, "job.json")
            if not os.path.exists(p):
                continue
            try:
                with open(p, "r", encoding="utf-8") as f:
                    job = Job(**json.load(f))
            except Exception:
                continue
            if job.status in STATUS_ACTIVE:
                job.status, job.error = "failed", "The server stopped while this job was running."
            self.jobs[job.id] = job
            self.seq = max(self.seq, job.seq or 0)

    # --- API ------------------------------------------------------------------------------------------------------
    def create(self, payload: dict) -> Job:
        kind = (payload.get("kind") or ("auto" if payload.get("prompt") and not payload.get("source") else "both"))
        kind = kind.lower()
        if kind not in KINDS:
            raise ValueError(f"kind must be one of {', '.join(KINDS)}")
        source = (payload.get("source") or payload.get("url") or "").strip()
        prompt = (payload.get("prompt") or "").strip()
        if not source and not prompt:
            raise ValueError("Give a video link/file in 'source' or describe what to make in 'prompt'.")
        if source and kind == "auto":
            kind = "both"  # a clip: read both the body motion and the effect
        if not prompt and kind in NEEDS_PROMPT:
            raise ValueError(f"'{kind}' jobs need a 'prompt' describing what to make.")
        key = json.dumps([kind, source, prompt, payload.get("options") or {}, payload.get("name") or "",
                          payload.get("client") or ""], sort_keys=True, default=str)
        with self.lock:
            seen = self.recent.get(key)
            if seen and _now() - seen[1] < DUPLICATE_WINDOW and seen[0] in self.jobs:
                return self.jobs[seen[0]]  # pressed twice: the same job, not a second copy in the place
            self.seq += 1
            job = Job(id=uuid.uuid4().hex[:10], seq=self.seq, kind=kind, source=source or None, prompt=prompt or None,
                      options=payload.get("options") or {}, client=(payload.get("client") or "api")[:60],
                      name=_safe_name(payload.get("name") or "", ""), status="queued", progress=0.0,
                      message="Waiting in line", created=_now(), updated=_now())
            self.jobs[job.id] = job
            self.recent = {k: v for k, v in self.recent.items() if _now() - v[1] < DUPLICATE_WINDOW}
            self.recent[key] = (job.id, _now())
            self._save(job)
            self.changed.notify_all()
        self.q.put(job.id)
        return job

    def preview(self, payload: dict) -> dict:
        """What words would make, worked out now without queueing a job (so nothing gets built in Studio):
        {"plan": the router's reading, "message": what a job would report, "result": the job result it would have}."""
        from . import router

        kind = (payload.get("kind") or "auto").lower()
        prompt = (payload.get("prompt") or "").strip()
        if kind not in KINDS:
            raise ValueError(f"kind must be one of {', '.join(KINDS)}")
        if not prompt:
            raise ValueError("Give the words to read in 'prompt'.")
        job = Job(id="preview", seq=0, kind=kind, source=None, prompt=prompt, options=payload.get("options") or {},
                  client="preview", name=_safe_name(payload.get("name") or "", ""), status="running", progress=0.0,
                  message="", created=_now(), updated=_now())
        result = {"jobId": None, "kind": kind, "name": job.name, "client": "preview", "source": None,
                  "animation": None, "vfx": None}
        out = {"plan": router.plan(prompt, kind="auto" if kind == "both" else kind)}

        def capture(_job, res, message):
            out["result"], out["message"] = res, message

        if kind in ("generate", "model", "cutscene"):
            self._run_prompt(job, result, job.options, finish=capture)
        else:
            self._run_text(job, result, job.options, finish=capture)
        return out

    def get(self, job_id: str) -> Job | None:
        with self.lock:
            return self.jobs.get(job_id)

    def list(self, since: int = 0, status: str | None = None, undelivered: bool = False, limit: int = 50):
        with self.lock:
            items = sorted(self.jobs.values(), key=lambda j: -(j.seq or 0))
            if since:
                items = [j for j in items if (j.seq or 0) > since]
            if status:
                wanted = set(status.split(","))
                items = [j for j in items if j.status in wanted]
            if undelivered:
                items = [j for j in items if not j.delivered]
            return [j.to_dict() for j in items[:limit]]

    def result(self, job_id: str) -> dict | None:
        p = os.path.join(self._dir(job_id), "result.json")
        if not os.path.exists(p):
            return None
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f)

    def file_path(self, job_id: str, name: str) -> str | None:
        if not re.match(r"^[A-Za-z0-9_.-]+$", name):
            return None
        p = os.path.join(self._dir(job_id), name)
        return p if os.path.isfile(p) else None

    def mark_delivered(self, job_id: str, info: dict | None) -> Job | None:
        with self.lock:
            job = self.jobs.get(job_id)
            if not job:
                return None
            job.delivered = True
            job.deliveredInfo = info or {}
            job.buildError = None
            job.updated = _now()
            self._save(job)
            self.changed.notify_all()
            return job

    def claim(self, job_id: str, studio: str, release: bool = False, error: str | None = None,
              force: bool = False) -> tuple[bool, Job | None, str]:
        """One Studio window builds each job: the first claim wins (claims expire after 90 s if never delivered).
        A window that could not build it releases the claim with the error, which bots then see as buildError.
        A job given back unbuilt 3 times in 2 minutes is paused, so a Studio that keeps failing (an older plugin
        retries on every poll) stops hammering it; a person pressing Build here (force) can always retry."""
        with self.lock:
            job = self.jobs.get(job_id)
            if not job:
                return False, None, "No such job"
            now = _now()
            if release:
                job.claimedBy, job.claimedAt = None, None
                if error:
                    job.buildError = str(error)[:500]
                self.releases.setdefault(job_id, []).append(now)
                job.updated = now
                self._save(job)
                self.changed.notify_all()
                return True, job, ""
            recent = [t for t in self.releases.get(job_id, []) if now - t < 120]
            self.releases[job_id] = recent
            if len(recent) >= 3 and not force:
                return False, job, ("Paused: Studio could not build this job 3 times in a row. Update the ClipForge "
                                    "plugin, then press Build here on it.")
            fresh = job.claimedAt and now - job.claimedAt < 90
            if job.delivered or (job.claimedBy and fresh and job.claimedBy != studio):
                return False, job, "Already taken by " + str(job.claimedBy)
            job.claimedBy, job.claimedAt = studio or "studio", now
            self._save(job)
            self.changed.notify_all()
            return True, job, ""

    def delete(self, job_id: str) -> bool:
        with self.lock:
            job = self.jobs.pop(job_id, None)
            if not job:
                return False
            if job.status in STATUS_ACTIVE:
                job.status = "cancelled"
            self.changed.notify_all()
        shutil.rmtree(self._dir(job_id), ignore_errors=True)
        return True

    def wait_for(self, job_id: str, timeout: float) -> Job | None:
        deadline = _now() + timeout
        with self.lock:
            while True:
                job = self.jobs.get(job_id)
                if job is None or job.status not in STATUS_ACTIVE:
                    return job
                left = deadline - _now()
                if left <= 0:
                    return job
                self.changed.wait(min(left, 1.0))

    def _update(self, job: Job, **kw):
        with self.lock:
            for k, v in kw.items():
                setattr(job, k, v)
            job.updated = _now()
            self._save(job)
            self.changed.notify_all()

    # --- worker ---------------------------------------------------------------------------------------------------
    def _worker(self):
        while True:
            job_id = self.q.get()
            job = self.get(job_id)
            if job is None or job.status != "queued":
                continue
            try:
                self._run(job)
            except Exception as e:  # report every failure on the job, never kill the worker
                traceback.print_exc()
                self._update(job, status="failed", error=str(e)[:800], message="Failed")

    def _run(self, job: Job):
        from . import prompts

        d = self._dir(job.id)
        os.makedirs(d, exist_ok=True)
        opts = job.options or {}
        result = {"jobId": job.id, "kind": job.kind, "name": job.name, "client": job.client, "source": None,
                  "animation": None, "vfx": None}

        def stage(status, lo, hi):
            def cb(frac, msg):
                if job.status == "cancelled":
                    raise RuntimeError("Cancelled")
                self._update(job, status=status, progress=round(lo + (hi - lo) * max(0.0, min(1.0, frac)), 3),
                             message=msg)
            return cb

        if job.kind in ("generate", "model") or (job.kind == "cutscene" and not job.source):
            self._run_prompt(job, result, opts)
            return

        if not job.source:
            self._run_text(job, result, opts)
            return

        from . import fetch
        self._update(job, status="downloading", progress=0.02, message="Getting the clip")
        clip, meta = fetch.fetch(job.source, d, opts, stage("downloading", 0.02, 0.25))
        result["source"] = meta
        job.meta = meta
        base_name = job.name or _safe_name(meta.get("title") or "", "Clip")

        warnings = []
        if job.kind == "cutscene":
            from . import catalog
            from .cutscene_video import analyze_cutscene
            spec = catalog.cutscene_from_prompt(job.prompt) if job.prompt else {}
            cs = analyze_cutscene(clip, opts, stage("analyzing", 0.25, 0.97), who=opts.get("who") or "Target",
                                  name=(job.name or base_name) + "Cutscene", lines=spec.get("lines"),
                                  effect=opts.get("effect") or spec.get("effect"))
            cs["source"] = meta
            result["cutscene"] = cs
            result["name"] = job.name = cs["name"]
            a = cs["analysis"]
            moves = sorted({sh["move"] for sh in a["shots"]})
            self._finish(job, result, f"Made a {len(cs['shots'])}-shot cutscene ({', '.join(moves)}; "
                                      f"{a['flashes']} flashes, {a['shakes']} shakes) from the clip")
            return
        if job.kind in ("animation", "both"):
            from .motion import AnimOptions, build_animation
            from .pose import extract_pose
            try:
                pose = extract_pose(clip, stage("tracking", 0.25, 0.75 if job.kind == "animation" else 0.6),
                                    max_seconds=float(opts.get("maxSeconds") or config.MAX_VIDEO_SECONDS))
                self._update(job, status="building", message="Retargeting to Roblox and cleaning up keys")
                aopts = AnimOptions.from_dict(opts)
                aopts.name = (job.name or base_name) + ("" if job.kind == "animation" else "Anim")
                anim = build_animation(pose, aopts)
                anim["source"] = meta
                result["animation"] = anim
            except ValueError as e:
                if job.kind == "animation":
                    raise
                warnings.append(f"No animation: {e}")  # 'both' still delivers the VFX

        if job.kind in ("vfx", "both"):
            from .vfx_analyze import analyze_vfx
            lo = 0.75 if job.kind == "both" else 0.25
            cfg = analyze_vfx(clip, opts, stage("analyzing", lo, 0.97), os.path.join(d, "sheet.jpg"))
            cfg["name"] = (job.name or base_name) + ("" if job.kind == "vfx" else "VFX")
            cfg["source"] = meta
            if job.prompt:  # a prompt can steer the read ("make it purple", "slash")
                steer = prompts.config_from_prompt(job.prompt)
                if any(steer["analysis"]["scores"].values()):
                    cfg.update({k: steer[k] for k in ("base", "archetype", "description", "parts")})
                if any(c in job.prompt.lower() for c in prompts.COLORS):
                    cfg["palette"] = steer["palette"]
            result["vfx"] = cfg

        result["name"] = job.name or base_name
        result["warnings"] = warnings
        job.name = result["name"]
        bits = []
        if result["animation"]:
            bits.append(f"{len(result['animation']['keyTimes'])}-key animation")
        if result["vfx"]:
            bits.append(f"{result['vfx']['description']} VFX")
        msg = "Made a " + " and a ".join(bits) if bits else "Nothing usable in this clip"
        if warnings:
            msg += " (" + "; ".join(warnings) + ")"
        self._finish(job, result, msg)

    def _run_text(self, job: Job, result: dict, opts: dict, finish=None):
        """No video: words -> an animation from the move library and/or an effect (linked as an ability that fires the
        effect on the animation's Hit marker), or whatever else the router reads in a free-form message."""
        from . import prompts, router, text_motion

        plan = router.plan(job.prompt, kind=job.kind)
        if not any(plan[k] for k in ("animation", "vfx", "generate", "model", "cutscene")):
            raise ValueError(plan["reason"] or router.NOTHING)
        for other in ("generate", "model", "cutscene"):
            if plan[other]:
                self._run_prompt(job, result, opts, kind=other, finish=finish)
                return
        made, anim, notes = [], None, []
        if plan["animation"]:
            try:
                anim = text_motion.from_prompt(job.prompt, (job.name + ("Anim" if plan["vfx"] else "")) if job.name else None,
                                               speed=opts.get("speed"), mirror=opts.get("mirror"), loop=opts.get("loop"))
            except ValueError as e:
                if not plan["vfx"] or "No move matched" not in str(e):
                    raise
                notes.append("no move in the library matched the words, so only the effect was made")
            if anim:
                result["animation"] = anim
                made.append(f"{_a(anim['description'].lower())} animation ({anim['duration']:.2f} s)")
        if plan["vfx"]:
            vp = router.vfx_prompt_for(job.prompt, anim["moves"][0] if anim else None)
            cfg = prompts.config_from_prompt(vp, (job.name + ("VFX" if anim else "")) if job.name else None)
            cfg["prompt"] = job.prompt
            result["vfx"] = cfg
            made.append(f"{_a(cfg['description'])} effect")
        if anim and plan["vfx"] and anim.get("markers"):
            fx, attach = text_motion.MOVE_FX.get(anim["moves"][-1], ("hitspark", "Front"))
            base = result["vfx"].get("base")
            if attach in ("RightHand", "LeftHand") and base != fx and base not in PER_HIT_FX:
                attach = "Front"  # a summoned black hole or an explosion goes out in front, not on the hand
            hits = [m["t"] for m in anim["markers"] if m["name"] == "Hit"]
            marker, at = "Hit", hits
            if len(hits) > 1 and base not in PER_HIT_FX:
                # a one-off effect ("clap then summon a black hole") fires once, on the last hit: its own marker
                marker, at = "Fx", [hits[-1]]
                anim["markers"] = anim["markers"] + [{"name": "Fx", "t": hits[-1]}]
            result["ability"] = {"marker": marker, "attach": attach, "at": at}
            made.append("linked as an ability")
        if not made:
            raise ValueError("Nothing to make from that. Name a move (punch, backflip, wave...) or an effect.")
        job.name = job.name or (anim["name"] if anim else result["vfx"]["name"])
        result["name"] = job.name
        if notes:
            result["warnings"] = notes
        (finish or self._finish)(job, result, "Made " + ", ".join(made) + (f" ({'; '.join(notes)})" if notes else ""))

    def _run_prompt(self, job: Job, result: dict, opts: dict, kind: str | None = None, finish=None):
        """Prompt-only kinds: the description Studio will build, worked out here so the bot hears what it gets."""
        from . import catalog

        kind = kind or job.kind
        if kind == "generate":
            d = catalog.generate_desc(job.prompt, seed=int(opts.get("seed") or 1), mode=opts.get("mode"),
                                      chromatic=opts.get("chromatic"))
            if opts.get("scale"):
                d["scale"] = float(opts["scale"])
            name = job.name or d["name"]
            desc = catalog.describe_generate(d)
            result["vfx"] = {"type": "vfx", "version": 1, "name": name, "generate": d, "description": "generated " + desc,
                             "scale": 1.0, "speed": float(opts.get("speed") or 1.0), "intensity": 1.0,
                             "prompt": job.prompt, "analysis": {"confidence": 1.0}}
            message = f"Generated a {desc} VFX"
        elif kind == "model":
            m = catalog.model_from_prompt(job.prompt, job.name or None)
            for k in ("type", "style", "glow", "scale"):
                if opts.get(k) not in (None, ""):
                    m[k] = opts[k]
            if m["style"] not in ("steel", "dark", "gold", "crystal", "energy", "wood"):
                raise ValueError(f"Unknown model style '{m['style']}' (steel, dark, gold, crystal, energy or wood)")
            m["scale"] = float(min(max(float(m.get("scale") or 1), 0.3), 4))
            if m["type"] not in {t["id"] for t in catalog.catalog()["models"]}:
                raise ValueError(f"Unknown model type '{m['type']}'")
            result["model"] = m
            name = m["name"]
            message = f"Made a {catalog.describe_model(m)} model"
        else:  # cutscene from a prompt: one of the plugin's templates, with the lines and effect the prompt names
            c = catalog.cutscene_from_prompt(job.prompt, who=opts.get("who") or "Target", name=job.name or None)
            for k in ("template", "title", "sub", "effect"):
                if opts.get(k):
                    c[k] = opts[k]
            result["cutscene"] = c
            name = c["name"]
            said = f", {len(c['lines'])} line{'s' if len(c['lines']) != 1 else ''}" if c["lines"] else ""
            fx = f", {c['effect']} effect" if c.get("effect") else ""
            message = f"Made a {c['templateTitle'].lower()} cutscene{said}{fx}"
        result["name"] = job.name = name
        (finish or self._finish)(job, result, message)

    def _finish(self, job: Job, result: dict, message: str):
        d = self._dir(job.id)
        with open(os.path.join(d, "result.json"), "w", encoding="utf-8") as f:
            json.dump(result, f, separators=(",", ":"))
        summary = {}
        if result.get("animation"):
            a = result["animation"]
            summary["animation"] = {"name": a["name"], "duration": a["duration"], "keys": len(a["keyTimes"]),
                                    "quality": a.get("quality")}
        if result.get("vfx"):
            v = result["vfx"]
            summary["vfx"] = {"name": v.get("name"), "base": v.get("base"), "archetype": v.get("archetype"),
                              "description": v.get("description"), "palette": v.get("palette"),
                              "confidence": v.get("analysis", {}).get("confidence"), "sheet": v.get("sheet")}
        if result.get("cutscene"):
            c = result["cutscene"]
            summary["cutscene"] = {"name": c.get("name"), "template": c.get("template"),
                                   "shots": len(c["shots"]) if c.get("shots") else None,
                                   "events": len(c["events"]) if c.get("events") else None,
                                   "lines": c.get("lines"), "effect": c.get("effect")}
        if result.get("model"):
            m = result["model"]
            summary["model"] = {k: m.get(k) for k in ("name", "type", "style", "glow", "scale")}
        self._update(job, status="done", progress=1.0, message=message, hasResult=True, summary=summary)
