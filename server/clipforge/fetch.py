"""Get a clip onto disk: social links through yt-dlp (YouTube, Shorts, TikTok, Instagram, X, Reddit, Twitch clips,
Streamable, Discord CDN links...), or a local file. Every clip is normalised with ffmpeg to 30 fps, <= 720p, no audio,
cut to the requested start/end."""
from __future__ import annotations

import os
import re
import shutil
import subprocess
from typing import Callable
from urllib.parse import urlparse

from .config import MAX_VIDEO_SECONDS

PLATFORMS = {
    "youtube.com": "YouTube", "youtu.be": "YouTube", "tiktok.com": "TikTok", "instagram.com": "Instagram",
    "twitter.com": "X", "x.com": "X", "reddit.com": "Reddit", "v.redd.it": "Reddit", "twitch.tv": "Twitch",
    "streamable.com": "Streamable", "facebook.com": "Facebook", "fb.watch": "Facebook", "vimeo.com": "Vimeo",
    "discordapp.com": "Discord", "discordapp.net": "Discord", "medal.tv": "Medal", "bilibili.com": "Bilibili",
}


class FetchError(RuntimeError):
    pass


def platform_of(url: str) -> str:
    host = (urlparse(url).hostname or "").lower()
    for dom, name in PLATFORMS.items():
        if host == dom or host.endswith("." + dom):
            return name
    return host or "file"


def is_url(s: str) -> bool:
    return bool(re.match(r"^https?://", (s or "").strip(), re.I))


def _ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if not exe:
        raise FetchError("ffmpeg is not installed (winget install Gyan.FFmpeg).")
    return exe


def normalise(src: str, dst: str, start: float | None, end: float | None, max_seconds: float) -> None:
    cmd = [_ffmpeg(), "-hide_banner", "-loglevel", "error", "-y"]
    if start:
        cmd += ["-ss", f"{float(start):.3f}"]
    cmd += ["-i", src]
    dur = None
    if end is not None and end > (start or 0):
        dur = float(end) - float(start or 0)
    dur = min(dur, max_seconds) if dur else max_seconds
    cmd += ["-t", f"{dur:.3f}", "-vf", "fps=30,scale=-2:'min(720,ih)'", "-an", "-c:v", "libx264",
            "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p", dst]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0 or not os.path.exists(dst):
        raise FetchError("ffmpeg could not read the clip: " + (p.stderr or "").strip()[-400:])


def fetch(source: str, job_dir: str, options: dict | None = None,
          progress: Callable[[float, str], None] | None = None) -> tuple[str, dict]:
    """Returns (path to the normalised clip, metadata)."""
    options = options or {}
    start = options.get("start")
    end = options.get("end")
    start = float(start) if start not in (None, "") else None
    end = float(end) if end not in (None, "") else None
    max_seconds = float(options.get("maxSeconds") or MAX_VIDEO_SECONDS)
    out = os.path.join(job_dir, "clip.mp4")
    source = (source or "").strip().strip('"')

    if not is_url(source):
        if not os.path.isfile(source):
            raise FetchError(f"Not a link and not a file on this computer: {source}")
        if progress:
            progress(0.5, "Preparing the local clip")
        normalise(source, out, start, end, max_seconds)
        return out, {"platform": "file", "title": os.path.basename(source), "url": None}

    try:
        import yt_dlp
    except ImportError as e:  # pragma: no cover
        raise FetchError("yt-dlp is not installed (run setup.ps1).") from e

    platform = platform_of(source)
    meta = {"platform": platform, "url": source, "title": None, "uploader": None, "duration": None}

    def hook(d):
        if not progress:
            return
        if d.get("status") == "downloading":
            total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
            done = d.get("downloaded_bytes") or 0
            frac = (done / total) if total else 0.0
            progress(min(0.95, 0.05 + 0.9 * frac), f"Downloading from {platform} ({int(frac * 100)}%)")
        elif d.get("status") == "finished":
            progress(0.97, "Download finished")

    ydl_opts = {
        "format": "bv*[height<=720]/b[height<=720]/bv*/b",
        "outtmpl": os.path.join(job_dir, "source.%(ext)s"),
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "max_filesize": 300 * 1024 * 1024,
        "progress_hooks": [hook],
        "retries": 3,
        "socket_timeout": 30,
    }
    cookies = os.environ.get("CLIPFORGE_COOKIES")
    if cookies and os.path.isfile(cookies):
        ydl_opts["cookiefile"] = cookies  # only if YOU set it: some Instagram/TikTok posts need a login
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(source, download=False)
            if info.get("_type") == "playlist":
                entries = [e for e in (info.get("entries") or []) if e]
                if not entries:
                    raise FetchError("That link is a playlist with no playable videos.")
                info = entries[0]
            meta.update({"title": info.get("title"), "uploader": info.get("uploader") or info.get("channel"),
                         "duration": info.get("duration"), "id": info.get("id")})
            duration = info.get("duration") or 0
            seg_start = start or 0.0
            seg_end = end
            if duration and not seg_end and duration - seg_start > max_seconds:
                seg_end = seg_start + max_seconds
                meta["note"] = f"Only the first {int(max_seconds)} s were used (set start/end to pick a part)."
            if seg_start or seg_end:
                ydl.params["download_ranges"] = yt_dlp.utils.download_range_func(
                    None, [(seg_start, seg_end if seg_end else duration or seg_start + max_seconds)])
                ydl.params["force_keyframes_at_cuts"] = True
            ydl.process_ie_result(info, download=True)
    except FetchError:
        raise
    except Exception as e:
        msg = str(e)
        if "login" in msg.lower() or "cookies" in msg.lower() or "private" in msg.lower():
            msg += " | This post needs a login: export cookies.txt from your browser and set CLIPFORGE_COOKIES."
        raise FetchError(f"Could not download from {platform}: {msg[:500]}") from e

    files = [f for f in os.listdir(job_dir) if f.startswith("source.")]
    if not files:
        raise FetchError("The download produced no video file.")
    src = os.path.join(job_dir, sorted(files, key=lambda f: -os.path.getsize(os.path.join(job_dir, f)))[0])
    if progress:
        progress(0.98, "Normalising the clip")
    # the download is already cut to the range, so don't cut again
    normalise(src, out, None, None, max_seconds)
    try:
        os.remove(src)
    except OSError:
        pass
    return out, meta
