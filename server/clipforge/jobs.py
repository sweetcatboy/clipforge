"""Job queue: bots and the Studio plugin submit jobs, a worker turns clips into animation/VFX data, the plugin
builds finished jobs in Studio and marks them delivered."""
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

KINDS = ("animation", "vfx", "both")
STATUS_ACTIVE = ("queued", "downloading", "tracking", "analyzing", "building")


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
              "claimedBy", "claimedAt")

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
        kind = (payload.get("kind") or ("vfx" if payload.get("prompt") and not payload.get("source") else "both"))
        kind = kind.lower()
        if kind not in KINDS:
            raise ValueError(f"kind must be one of {', '.join(KINDS)}")
        source = (payload.get("source") or payload.get("url") or "").strip()
        prompt = (payload.get("prompt") or "").strip()
        if not source and not prompt:
            raise ValueError("Give a video link/file in 'source' or describe an effect in 'prompt'.")
        if not source and kind != "vfx":
            raise ValueError("Animations need a video 'source' (a prompt can only make VFX).")
        with self.lock:
            self.seq += 1
            job = Job(id=uuid.uuid4().hex[:10], seq=self.seq, kind=kind, source=source or None, prompt=prompt or None,
                      options=payload.get("options") or {}, client=(payload.get("client") or "api")[:60],
                      name=_safe_name(payload.get("name") or "", ""), status="queued", progress=0.0,
                      message="Waiting in line", created=_now(), updated=_now())
            self.jobs[job.id] = job
            self._save(job)
            self.changed.notify_all()
        self.q.put(job.id)
        return job

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
            job.updated = _now()
            self._save(job)
            self.changed.notify_all()
            return job

    def claim(self, job_id: str, studio: str, release: bool = False) -> tuple[bool, Job | None]:
        """One Studio window builds each job: the first claim wins (claims expire after 90 s if never delivered)."""
        with self.lock:
            job = self.jobs.get(job_id)
            if not job:
                return False, None
            if release:
                job.claimedBy, job.claimedAt = None, None
                self._save(job)
                return True, job
            fresh = job.claimedAt and _now() - job.claimedAt < 90
            if job.delivered or (job.claimedBy and fresh and job.claimedBy != studio):
                return False, job
            job.claimedBy, job.claimedAt = studio or "studio", _now()
            self._save(job)
            self.changed.notify_all()
            return True, job

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

        if not job.source:
            cfg = prompts.config_from_prompt(job.prompt, job.name or None)
            job.name = job.name or cfg["name"]
            cfg["name"] = job.name
            result["vfx"] = cfg
            result["name"] = job.name
            self._finish(job, result, f"Made a {cfg['description']} from the prompt")
            return

        from . import fetch
        self._update(job, status="downloading", progress=0.02, message="Getting the clip")
        clip, meta = fetch.fetch(job.source, d, opts, stage("downloading", 0.02, 0.25))
        result["source"] = meta
        job.meta = meta
        base_name = job.name or _safe_name(meta.get("title") or "", "Clip")

        warnings = []
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
                              "palette": v.get("palette"), "confidence": v.get("analysis", {}).get("confidence"),
                              "sheet": v.get("sheet")}
        self._update(job, status="done", progress=1.0, message=message, hasResult=True, summary=summary)
