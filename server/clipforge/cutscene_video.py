"""Video -> cutscene: the clip's editing rhythm and camera language, re-shot around your own character in Roblox.

Reads hard cuts, how the camera moves in each shot (push in, pull out, pan/orbit, tilt, locked off), how close the
framing is (close-up, medium, full body, wide: from a body pose on each shot when one is found), hand-held shake,
white flashes and fades to black. Each shot becomes a ClipForge camera shot on the same beat; shake, flashes and fades
become events. Quoted lines in the prompt become dialogue on successive shots."""
from __future__ import annotations

import math
from typing import Callable

import numpy as np

# framing -> distance, camera height, look height, field of view (studs for a 5.2-stud character; the plugin scales
# them with the filmed character's size)
FRAMING = {
    "close": (3.6, 1.6, 1.5, 40),
    "medium": (5.5, 1.3, 1.1, 40),
    "full": (9.5, 0.9, 0.4, 42),
    "wide": (18.0, 4.0, 0.6, 50),
}
SIDES = (25, -30, 12, -18, 35, -22, 5, -35)  # camera angles around the subject, varied shot to shot


def _hist(hsv):
    import cv2
    h = cv2.calcHist([hsv], [0, 1, 2], None, [16, 4, 4], [0, 180, 0, 256, 0, 256])
    cv2.normalize(h, h)
    return h


def _bhatt(a, b) -> float:
    import cv2
    return float(cv2.compareHist(a, b, cv2.HISTCMP_BHATTACHARYYA))


def _motion(prev_gray, gray):
    """Global camera motion between two frames: (dx, dy) in frame widths/heights, zoom factor, ok."""
    import cv2
    pts = cv2.goodFeaturesToTrack(prev_gray, maxCorners=160, qualityLevel=0.01, minDistance=6)
    if pts is None or len(pts) < 12:
        return 0.0, 0.0, 1.0, False
    nxt, st, _ = cv2.calcOpticalFlowPyrLK(prev_gray, gray, pts, None, winSize=(15, 15), maxLevel=2)
    good = st.reshape(-1) == 1
    if good.sum() < 10:
        return 0.0, 0.0, 1.0, False
    m, inliers = cv2.estimateAffinePartial2D(pts[good], nxt[good], method=cv2.RANSAC, ransacReprojThreshold=2.0)
    if m is None or inliers is None or inliers.sum() < 8:
        return 0.0, 0.0, 1.0, False
    h, w = gray.shape[:2]
    scale = math.hypot(m[0, 0], m[1, 0])
    if not 0.8 < scale < 1.25:
        return 0.0, 0.0, 1.0, False
    # translation of the frame centre (the affine moves points about the origin, so correct for the zoom)
    cx, cy = w / 2, h / 2
    ncx = m[0, 0] * cx + m[0, 1] * cy + m[0, 2]
    ncy = m[1, 0] * cx + m[1, 1] * cy + m[1, 2]
    return (ncx - cx) / w, (ncy - cy) / h, scale, True


def _subject_size(frames_rgb) -> list[tuple[str | None, float | None]]:
    """For one frame per shot: framing from the visible body (close / medium / full / wide) and the subject's x."""
    out = [(None, None)] * len(frames_rgb)
    try:
        import mediapipe as mp
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision

        from .pose import _model_path
        model = _model_path()
        if not model:
            return out
        det = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
            base_options=mp_python.BaseOptions(model_asset_path=model), running_mode=vision.RunningMode.IMAGE,
            num_poses=1, min_pose_detection_confidence=0.5))
    except Exception:
        return out
    try:
        res = []
        for rgb in frames_rgb:
            r = det.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb)))
            if not r.pose_landmarks:
                res.append((None, None))
                continue
            lm = r.pose_landmarks[0]

            def seen(*idx):
                return all((getattr(lm[i], "visibility", 1.0) or 0) > 0.55 and 0 <= lm[i].y <= 1 for i in idx)
            xs = [p.x for p in lm if (getattr(p, "visibility", 1.0) or 0) > 0.55]
            cx = float(np.clip(np.mean(xs), 0, 1)) if xs else None
            if seen(27) or seen(28):  # an ankle in frame
                ys = [p.y for p in lm if (getattr(p, "visibility", 1.0) or 0) > 0.55]
                tall = (max(ys) - min(ys)) if ys else 1.0
                res.append(("full" if tall > 0.55 else "wide", cx))
            elif seen(25) or seen(26) or seen(23, 24):  # knees or hips
                res.append(("medium", cx))
            else:
                res.append(("close", cx))
        return res
    except Exception:
        return out
    finally:
        try:
            det.close()
        except Exception:
            pass


def _frames_at(video_path: str, indices: list[int], width: int = 480) -> list:
    """RGB frames at the given indices (a second, sequential read: cheaper than keeping every frame in memory)."""
    import cv2
    wanted = {k: None for k in indices}
    cap = cv2.VideoCapture(video_path)
    k, last = 0, max(indices) if indices else -1
    while k <= last:
        ok, frame = cap.read()
        if not ok:
            break
        if k in wanted:
            h0, w0 = frame.shape[:2]
            small = cv2.resize(frame, (min(w0, width), int(min(w0, width) * h0 / w0)), interpolation=cv2.INTER_AREA)
            wanted[k] = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
        k += 1
    cap.release()
    blank = np.zeros((8, 8, 3), np.uint8)
    return [wanted[k] if wanted[k] is not None else blank for k in indices]


def _segments(mask: np.ndarray, min_len: int = 1, gap: int = 0) -> list[tuple[int, int]]:
    segs, start = [], None
    for i, on in enumerate(list(mask) + [False]):
        if on and start is None:
            start = i
        elif not on and start is not None:
            segs.append([start, i])
            start = None
    merged = []
    for s in segs:
        if merged and s[0] - merged[-1][1] <= gap:
            merged[-1][1] = s[1]
        else:
            merged.append(s)
    return [(a, b) for a, b in merged if b - a >= min_len]


def analyze_cutscene(video_path: str, options: dict | None = None,
                     progress: Callable[[float, str], None] | None = None, who: str = "Target",
                     name: str | None = None, lines: list[str] | None = None, effect: str | None = None) -> dict:
    import cv2

    options = options or {}
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Could not open the video: {video_path}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    if fps <= 1 or fps > 240:
        fps = 30.0
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    limit = int(float(options.get("maxSeconds") or 60) * fps)

    hists, bright, motion = [], [], []
    prev_gray = None
    i = 0
    while i < limit:
        ok, frame = cap.read()
        if not ok:
            break
        h0, w0 = frame.shape[:2]
        small = cv2.resize(frame, (192, max(2, int(192 * h0 / w0))), interpolation=cv2.INTER_AREA)
        hsv = cv2.cvtColor(small, cv2.COLOR_BGR2HSV)
        gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
        hists.append(_hist(hsv))
        bright.append(float(hsv[..., 2].mean()) / 255.0)
        motion.append(_motion(prev_gray, gray) if prev_gray is not None else (0.0, 0.0, 1.0, False))
        prev_gray = gray
        i += 1
        if progress and i % 15 == 0:
            progress(min(0.85, i / max(1, min(total or limit, limit))), "Reading cuts and camera moves")
    cap.release()
    n = len(hists)
    if n < 6:
        raise ValueError("The clip is too short to read a cutscene from.")
    duration = n / fps
    bright = np.array(bright)

    # --- hard cuts: a jump in colour make-up that does not come straight back (that would be a flash) -----------
    dist = np.array([0.0] + [_bhatt(hists[k - 1], hists[k]) for k in range(1, n)])
    cuts = [0]
    min_gap = max(2, int(0.35 * fps))
    for k in range(1, n):
        local = np.median(dist[max(1, k - 15):k]) if k > 1 else 0.0
        if dist[k] > 0.5 or (dist[k] > 0.3 and dist[k] > 3.0 * local + 0.08):
            # a flash or a frame of blur: the picture comes straight back, or this frame is a return to just before
            back = k + 4 < n and _bhatt(hists[k - 1], hists[k + 4]) < 0.25
            returning = any(_bhatt(hists[j], hists[k]) < 0.25 for j in range(max(0, k - 7), k - 1))
            dark = bright[k] < 0.06 or bright[k - 1] < 0.06  # fades are handled as fades
            if not back and not returning and not dark and k - cuts[-1] >= min_gap:
                cuts.append(k)
    # a dip to black between two scenes is a cut too: the new shot starts where the picture comes back
    for a, b in _segments(bright < 0.05, min_len=2):
        if a > 0 and b < n:
            cuts.append(b)
    cuts = sorted(set(cuts))
    cuts = [c for idx, c in enumerate(cuts) if idx == 0 or c - cuts[idx - 1] >= min_gap]
    bounds = cuts + [n]

    # --- flashes and fades -------------------------------------------------------------------------------------------
    events = []
    k = 1
    while k < n:
        before = np.median(bright[max(0, k - 6):k])
        if bright[k] - before > 0.2 and bright[k] > 0.55:
            after = bright[k + 1:k + 9]
            if len(after) and after.min() - before < 0.1:
                events.append({"t": round(k / fps, 2), "type": "flash", "dur": 0.18})
                k += int(0.3 * fps)
                continue
        k += 1
    black = bright < 0.05
    for a, b in _segments(black, min_len=2):
        if a == 0:
            events.append({"t": 0, "type": "fade", "from": 1, "to": 0, "dur": round(max(0.3, b / fps), 2)})
        elif b >= n - 1:
            events.append({"t": round(max(0, a / fps - 0.35), 2), "type": "fade", "from": 0, "to": 1, "dur": 0.35})
        else:
            events.append({"t": round(max(0, a / fps - 0.3), 2), "type": "fade", "from": 0, "to": 1, "dur": 0.3})
            events.append({"t": round(b / fps, 2), "type": "fade", "from": 1, "to": 0, "dur": 0.35})

    # --- shake: jitter left after smoothing the camera path ----------------------------------------------------------
    mv = np.array([[m[0], m[1]] for m in motion])
    valid = np.array([m[3] for m in motion])
    for c in cuts:  # motion across a cut is meaningless
        valid[c] = False
    mv[~valid] = 0.0
    kern = np.ones(9) / 9.0
    smooth = np.stack([np.convolve(mv[:, j], kern, mode="same") for j in range(2)], axis=1)
    jitter = np.linalg.norm(mv - smooth, axis=1)
    jitter = np.convolve(jitter, np.ones(5) / 5.0, mode="same")
    shakes = 0
    for a, b in _segments(jitter > 0.008, min_len=max(2, int(0.12 * fps)), gap=int(0.2 * fps)):
        peak = float(jitter[a:b].max())
        amp = float(np.clip((peak - 0.004) * 60, 0.25, 1.2))
        events.append({"t": round(a / fps, 2), "type": "shake", "amp": round(amp, 2),
                       "dur": round(float(np.clip((b - a) / fps, 0.2, 1.0)), 2)})
        shakes += 1

    # --- per shot: camera move and framing ---------------------------------------------------------------------------
    if progress:
        progress(0.88, "Reading shot sizes")
    sizes = _subject_size(_frames_at(video_path, [(bounds[j] + bounds[j + 1] - 1) // 2 for j in range(len(cuts))]))
    shots, info = [], []
    for j in range(len(cuts)):
        a, b = bounds[j], bounds[j + 1]
        t0, dur = a / fps, (b - a) / fps
        seg = [motion[x] for x in range(a + 1, b) if valid[x]]
        pan = -sum(m[0] for m in seg)  # scene sliding left = camera turning/moving right
        tilt = sum(m[1] for m in seg)  # scene sliding down = camera rising/tilting up
        zoom = float(np.prod([m[2] for m in seg])) if seg else 1.0
        size, cx = sizes[j]
        size = size or ("full" if j % 2 == 0 else "medium")
        dist_, height, look, fov = FRAMING[size]
        ang = SIDES[j % len(SIDES)]
        if cx is not None and abs(cx - 0.5) > 0.15:
            ang = abs(ang) * (1 if cx < 0.5 else -1)  # subject off to one side: come round from that side
        if zoom > 1.12:
            move = "push in"
            shot = {"type": "push", "from": round(dist_ * min(2.2, zoom * 1.3), 2), "to": dist_, "angle": ang,
                    "height": height, "lookHeight": look, "fov": fov}
        elif zoom < 1 / 1.12:
            move = "pull out"
            shot = {"type": "push", "from": dist_, "to": round(dist_ * min(2.2, 1.3 / max(zoom, 0.3)), 2), "angle": ang,
                    "height": height, "lookHeight": look, "fov": fov}
        elif abs(pan) > 0.25:
            move = "orbit"
            span = float(np.clip(pan * 90, -110, 110))
            shot = {"type": "orbit", "radius": dist_, "height": height, "lookHeight": look, "from": ang,
                    "to": round(ang + span, 1), "fov": fov, "ease": "linear" if dur > 2.5 else "sineInOut"}
        elif abs(tilt) > 0.2:
            move = "tilt up" if tilt > 0 else "tilt down"
            r = math.radians(ang)
            px, pz = round(math.sin(r) * dist_, 2), round(-math.cos(r) * dist_, 2)
            lo, hi = look - 1.2, look + 1.2
            a_look, b_look = (lo, hi) if tilt > 0 else (hi, lo)
            shot = {"type": "dolly", "from": [px, height, pz, 0, round(a_look, 2), 0],
                    "to": [px, round(height + (0.8 if tilt > 0 else -0.4), 2), pz, 0, round(b_look, 2), 0], "fov": fov}
        else:
            move = "locked off"
            r = math.radians(ang)
            shot = {"type": "static", "cf": [round(math.sin(r) * dist_, 2), height, round(-math.cos(r) * dist_, 2),
                                             0, look, 0], "fov": fov}
        shot.update({"t": round(t0, 2), "dur": round(dur, 2), "target": who})
        shots.append(shot)
        info.append({"t": round(t0, 2), "dur": round(dur, 2), "move": move, "size": size, "pan": round(float(pan), 3),
                     "tilt": round(float(tilt), 3), "zoom": round(zoom, 3), "personFound": sizes[j][0] is not None})

    # --- dialogue and an effect on the biggest beat ------------------------------------------------------------------
    free = 0.0  # one line per shot, never two at once
    for idx, line in enumerate(lines or []):
        start = max(shots[idx]["t"] + 0.2 if idx < len(shots) else free, free)
        dur = round(min(max(2.0, len(line) * 0.06 + 1.2), 5.0), 2)
        events.append({"t": round(start, 2), "type": "text", "speaker": who, "text": line, "dur": dur})
        free = start + dur + 0.15
    if effect:
        beats = [e for e in events if e["type"] in ("flash", "shake")]
        beat = max(beats, key=lambda e: e.get("amp", 0.8)) if beats else None
        events.append({"t": beat["t"] if beat else round(shots[min(1, len(shots) - 1)]["t"] + 0.3, 2), "type": "fx",
                       "effect": effect, "at": who})
    events.sort(key=lambda e: e["t"])
    if progress:
        progress(1.0, "Cutscene ready")
    return {
        "type": "cutscene", "version": 1, "name": name or "ClipCutscene", "letterbox": True, "skippable": True,
        "who": who, "shots": shots, "events": events,
        "analysis": {"duration": round(duration, 2), "shots": info, "cuts": len(cuts) - 1,
                     "flashes": sum(1 for e in events if e["type"] == "flash"), "shakes": shakes,
                     "fades": sum(1 for e in events if e["type"] == "fade")},
    }
