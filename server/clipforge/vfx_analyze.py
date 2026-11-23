"""Read a VFX clip (a showcase, an anime attack, a game ability) and describe it as a ClipForge effect config.

The clip is not traced pixel by pixel. It is measured: the glow palette (white core, saturated body, deep tone),
the rhythm (wind-up, hit, decay, how many beats), the motion signature (bursting out, sucking in, sweeping,
travelling, rising, flickering) and the shape (round, long, thin). Those numbers pick one of the professional base
recipes in the plugin and fit it: recoloured to the clip's palette, retimed to its rhythm, scaled to its size and
turned to its direction. The result is an effect built the way VFX artists build them, in the clip's style.
"""
from __future__ import annotations

import colorsys
import math
import os
from typing import Callable

import numpy as np

ARCHETYPES = {
    # archetype: (plugin base recipe, nominal active seconds, description)
    "slash": ("slash", 0.45, "sword slash / crescent swipe"),
    "impact": ("impact", 0.9, "ground slam / punch impact"),
    "explosion": ("explosion", 1.4, "explosion / blast"),
    "aura": ("aura", 1.3, "aura / power-up / charge"),
    "beam": ("beam", 1.0, "beam / laser"),
    "lightning": ("lightning", 0.8, "lightning / electric strike"),
    "projectile": ("projectile", 0.8, "projectile / orb shot"),
    "fire": ("fire", 1.2, "fire eruption / flames"),
    "ice": ("icewater", 1.3, "ice / frost / water burst"),
    "dark": ("darkportal", 1.6, "dark void / portal / curse"),
    "holy": ("misc", 1.2, "holy light / heal / sparkle burst"),
}


def _hex(rgb):
    r, g, b = [int(max(0, min(255, round(c)))) for c in rgb]
    return "#{:02X}{:02X}{:02X}".format(r, g, b)


def _hsv(rgb):
    r, g, b = [c / 255.0 for c in rgb]
    return colorsys.rgb_to_hsv(r, g, b)


def _from_hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0, min(1, s)), max(0, min(1, v)))
    return (r * 255, g * 255, b * 255)


def _sig(x, lo, hi):
    """0 below lo, 1 above hi, smooth in between."""
    if hi == lo:
        return float(x >= hi)
    u = max(0.0, min(1.0, (x - lo) / (hi - lo)))
    return u * u * (3 - 2 * u)


def _smooth(x, sigma):
    if sigma <= 0 or len(x) < 3:
        return np.asarray(x, dtype=float)
    r = max(1, int(sigma * 3))
    k = np.exp(-(np.arange(-r, r + 1) ** 2) / (2 * sigma * sigma))
    k /= k.sum()
    xp = np.concatenate([np.repeat(x[:1], r), x, np.repeat(x[-1:], r)])
    return np.convolve(xp, k, mode="valid")


def _read_frames(path, width, start_frame=0, max_frames=None):
    import cv2
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        raise RuntimeError(f"Could not open the video: {path}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    if fps <= 1 or fps > 240:
        fps = 30.0
    if start_frame:
        cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)
    out = []
    while True:
        ok, f = cap.read()
        if not ok:
            break
        h, w = f.shape[:2]
        nh = max(2, int(round(h * width / w)))
        out.append(cv2.resize(f, (width, nh), interpolation=cv2.INTER_AREA))
        if max_frames and len(out) >= max_frames:
            break
    cap.release()
    return out, fps


def _pick_window(path, seconds):
    """For long clips: find the most energetic moment cheaply and return (start_frame, n_frames)."""
    import cv2
    frames, fps = _read_frames(path, 96)
    if len(frames) <= seconds * fps:
        return 0, len(frames), fps
    e = []
    for f in frames:
        hsv = cv2.cvtColor(f, cv2.COLOR_BGR2HSV)
        v = hsv[..., 2] / 255.0
        s = hsv[..., 1] / 255.0
        e.append(float(np.mean((v > 0.75) & ((s > 0.3) | (v > 0.93)))))
    e = _smooth(np.array(e), 3)
    peak = int(np.argmax(e))
    n = int(seconds * fps)
    start = max(0, min(len(frames) - n, peak - int(fps * 1.5)))
    return start, n, fps


def _kmeans_palette(pixels_bgr, weights, k=6):
    import cv2
    if len(pixels_bgr) < k * 4:
        return []
    if len(pixels_bgr) > 60000:
        idx = np.random.default_rng(1).choice(len(pixels_bgr), 60000, replace=False, p=weights / weights.sum())
        pixels_bgr = pixels_bgr[idx]
        weights = np.ones(len(idx))
    lab = cv2.cvtColor(pixels_bgr.reshape(-1, 1, 3).astype(np.uint8), cv2.COLOR_BGR2LAB).reshape(-1, 3)
    lab = lab.astype(np.float32)
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.5)
    _, labels, centers = cv2.kmeans(lab, k, None, crit, 3, cv2.KMEANS_PP_CENTERS)
    labels = labels.ravel()
    out = []
    for c in range(k):
        m = labels == c
        if not m.any():
            continue
        w = float(weights[m].sum())
        bgr = cv2.cvtColor(centers[c].reshape(1, 1, 3).astype(np.uint8), cv2.COLOR_LAB2BGR).reshape(3)
        rgb = (float(bgr[2]), float(bgr[1]), float(bgr[0]))
        h, s, v = _hsv(rgb)
        out.append({"rgb": rgb, "weight": w, "h": h, "s": s, "v": v, "L": float(centers[c][0]) / 255 * 100})
    total = sum(c["weight"] for c in out) or 1.0
    for c in out:
        c["weight"] /= total
    return out


def build_palette(clusters, smoke_rgb=None):
    """core / primary / secondary / deep from the glow clusters."""
    if not clusters:
        return {"core": "#FFFFFF", "primary": "#4FB2FF", "secondary": "#B66BFF", "deep": "#0B1E4A"}, 0.0
    sat = [c for c in clusters if c["s"] > 0.22 and c["v"] > 0.25]
    if sat:
        primary = max(sat, key=lambda c: c["weight"] * (0.5 + c["s"]))
    else:
        primary = max(clusters, key=lambda c: c["weight"])
    ph, ps, pv = primary["h"], primary["s"], primary["v"]
    # a body colour should be vivid: push weak saturation up, keep the hue
    body = _from_hsv(ph, max(ps, 0.55) if ps > 0.15 else ps, max(pv, 0.85))
    secondary = None
    for c in sorted(sat, key=lambda c: -c["weight"]):
        dh = abs(((c["h"] - ph + 0.5) % 1.0) - 0.5) * 360
        if c is not primary and dh > 35 and c["weight"] > 0.08:
            secondary = _from_hsv(c["h"], max(c["s"], 0.5), max(c["v"], 0.8))
            break
    if secondary is None:
        secondary = _from_hsv(ph + 0.04, min(1, ps * 0.75 + 0.1), min(1, pv * 1.05 + 0.1))
    brightest = max(clusters, key=lambda c: c["L"])
    if brightest["s"] < 0.25 and brightest["v"] > 0.8:
        core = _from_hsv(ph, min(0.12, brightest["s"]), 1.0)
    else:
        core = _from_hsv(ph, 0.08, 1.0)
    deep = _from_hsv(ph + 0.02, min(1.0, max(ps, 0.6) * 1.1), 0.2)
    if smoke_rgb is not None:
        sh, ss, sv = _hsv(smoke_rgb)
        if sv < 0.35:
            deep = _from_hsv(sh if ss > 0.15 else ph, max(ss, 0.5), max(0.08, min(sv, 0.22)))
    vividness = float(sum(c["weight"] * c["s"] for c in clusters))
    return {"core": _hex(core), "primary": _hex(body), "secondary": _hex(secondary), "deep": _hex(deep)}, vividness


def analyze_vfx(video_path: str, options: dict | None = None,
                progress: Callable[[float, str], None] | None = None, sheet_path: str | None = None) -> dict:
    import cv2

    options = options or {}
    if progress:
        progress(0.05, "Finding the effect in the clip")
    start, n, fps = _pick_window(video_path, float(options.get("windowSeconds", 8)))
    frames, fps = _read_frames(video_path, 240, start, n)
    T = len(frames)
    if T < 3:
        raise RuntimeError("The clip is too short to analyse.")
    H, W = frames[0].shape[:2]
    hsvs = [cv2.cvtColor(f, cv2.COLOR_BGR2HSV) for f in frames]
    V = np.stack([h[..., 2] for h in hsvs]).astype(np.float32) / 255.0
    S = np.stack([h[..., 1] for h in hsvs]).astype(np.float32) / 255.0
    sample = V[np.linspace(0, T - 1, min(T, 60)).astype(int)]
    bgV = np.median(sample, axis=0)

    ys, xs = np.mgrid[0:H, 0:W]
    energy, area, white, smoke = np.zeros(T), np.zeros(T), np.zeros(T), np.zeros(T)
    cx, cy, elong, angle = np.zeros(T), np.zeros(T), np.ones(T), np.zeros(T)
    radial, swirl, upward, flowmag = np.zeros(T), np.zeros(T), np.zeros(T), np.zeros(T)
    glow_masks = []
    prev_gray = None
    for t in range(T):
        v, s = V[t], S[t]
        glow = (v > 0.6) & (v - bgV > 0.1) & ((s > 0.28) | (v > 0.9))
        glow_masks.append(glow)
        energy[t] = float(np.sum(np.clip(v - bgV, 0, None) * glow)) / (H * W)
        area[t] = float(glow.mean())
        white[t] = float(np.mean(glow & (s < 0.22) & (v > 0.9)))
        smoke[t] = float(np.mean((v < bgV - 0.12) & (s < 0.3)))
        if glow.sum() > 12:
            px, py = xs[glow].astype(np.float64), ys[glow].astype(np.float64)
            cx[t], cy[t] = px.mean(), py.mean()
            cov = np.cov(np.stack([px, py]))
            ev, evec = np.linalg.eigh(cov)
            elong[t] = math.sqrt(max(ev[1], 1e-6) / max(ev[0], 1e-6))
            angle[t] = math.degrees(math.atan2(evec[1, 1], evec[0, 1]))
        else:
            cx[t], cy[t] = (cx[t - 1], cy[t - 1]) if t else (W / 2, H / 2)
        gray = cv2.cvtColor(frames[t], cv2.COLOR_BGR2GRAY)
        if prev_gray is not None:
            flow = cv2.calcOpticalFlowFarneback(prev_gray, gray, None, 0.5, 3, 13, 3, 5, 1.1, 0)
            m = cv2.dilate(glow.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
            if m.sum() > 12:
                fx, fy = flow[..., 0][m], flow[..., 1][m]
                rx, ry = xs[m] - cx[t], ys[m] - cy[t]
                rn = np.sqrt(rx * rx + ry * ry) + 1e-6
                mag = np.sqrt(fx * fx + fy * fy)
                mean_mag = float(mag.mean()) + 1e-6
                radial[t] = float(np.mean((fx * rx + fy * ry) / rn)) / mean_mag
                swirl[t] = float(np.mean((-fx * ry + fy * rx) / rn)) / mean_mag
                upward[t] = float(-np.mean(fy)) / mean_mag
                flowmag[t] = mean_mag / W * fps   # frame widths per second
        prev_gray = gray
        if progress and t % 15 == 0:
            progress(0.1 + 0.6 * t / T, f"Measuring the effect ({t}/{T} frames)")

    # --- rhythm ---------------------------------------------------------------------------------------------------
    E = _smooth(energy, 1.0)
    peak = int(np.argmax(E))
    peakE = float(E[peak]) or 1e-9
    thr = 0.12 * peakE
    onset = peak
    while onset > 0 and E[onset - 1] > thr:
        onset -= 1
    end = peak
    while end < T - 1 and E[end + 1] > thr:
        end += 1
    seg = slice(onset, end + 1)
    total = max(1, end - onset + 1) / fps
    attack = (peak - onset) / fps
    decay = (end - peak) / fps
    sustain = float(np.mean(E[seg] > 0.5 * peakE))
    dE = np.diff(E[seg]) if end > onset else np.array([0.0])
    flicker = float(np.std(dE) / (np.mean(E[seg]) + 1e-9))
    # beats: separate peaks above 35 % of the main one
    beats = []
    for i in range(1, T - 1):
        if E[i] >= E[i - 1] and E[i] > E[i + 1] and E[i] > 0.35 * peakE:
            if not beats or (i - beats[-1]) / fps > 0.15:
                beats.append(i)
            elif E[i] > E[beats[-1]]:
                beats[-1] = i
    w = E[seg] / (E[seg].sum() + 1e-9)
    radial_m = float(np.sum(radial[seg] * w))
    swirl_m = float(abs(np.sum(swirl[seg] * w)))
    upward_m = float(np.sum(upward[seg] * w))
    elong_peak = float(np.median(elong[max(onset, peak - 2):peak + 3]))
    angle_peak = float(np.median(angle[max(onset, peak - 2):peak + 3]))
    travel = float(math.hypot(cx[end] - cx[onset], cy[end] - cy[onset]) / W)
    area_peak = float(area[peak])
    white_ratio = float(white[peak] / max(area[peak], 1e-6))
    smoke_ratio = float(smoke[seg].max() / max(area_peak, 1e-6)) if area_peak > 0 else 0.0
    speed_m = float(np.median(flowmag[seg]))
    centre_low = float(cy[peak] / H)

    # --- palette ----------------------------------------------------------------------------------------------------
    pix, wts = [], []
    for t in range(onset, end + 1):
        g = glow_masks[t]
        if g.any():
            pix.append(frames[t][g])
            wts.append(V[t][g])
    if pix:
        clusters = _kmeans_palette(np.concatenate(pix), np.concatenate(wts).astype(np.float64) + 1e-3)
    else:
        clusters = []
    smoke_rgb = None
    smask = [(V[t] < bgV - 0.12) & (S[t] < 0.6) for t in range(onset, end + 1)]
    sm = [frames[onset + i][m] for i, m in enumerate(smask) if m.sum() > 30]
    if sm:
        allsm = np.concatenate(sm).astype(np.float64)
        b, g, r = np.median(allsm, axis=0)
        smoke_rgb = (r, g, b)
    palette, vividness = build_palette(clusters, smoke_rgb)
    ph, ps, pv = _hsv(tuple(int(palette["primary"][i:i + 2], 16) for i in (1, 3, 5)))
    hue = ph * 360

    # --- classify ---------------------------------------------------------------------------------------------------
    warm = 1.0 if (hue < 50 or hue >= 340) and ps > 0.3 else 0.0
    gold = 1.0 if 38 <= hue < 62 and ps > 0.3 else 0.0
    cold = 1.0 if 165 <= hue < 250 else 0.0
    purple = 1.0 if 250 <= hue < 330 else 0.0
    pale = 1.0 - min(1.0, vividness * 2.2)
    short = 1.0 - _sig(total, 0.6, 1.6)
    longish = _sig(total, 0.9, 2.0)
    held = float(np.sum(E[seg] > 0.5 * peakE)) / fps          # seconds the effect stays above half strength
    linear = _sig(elong_peak, 2.0, 4.0)                        # long thin shapes: slashes, beams, bolts
    round_ = 1.0 - _sig(elong_peak, 1.6, 3.0)                  # round shapes: bursts, rings, domes
    burst_gate = 0.35 + 0.65 * round_                          # outward flow from a long shape is a sweep, not a burst
    scores = {
        "slash": 1.6 * linear * short + 0.4 * _sig(swirl_m, 0.15, 0.5) + 0.3 * (1 - _sig(held, 0.3, 0.9))
        - 0.6 * _sig(travel, 0.25, 0.5),
        "impact": burst_gate * (1.0 * _sig(radial_m, 0.1, 0.45) + 0.5 * (1 - _sig(attack, 0.05, 0.25))
                                + 0.4 * short + 0.3 * _sig(white_ratio, 0.1, 0.4) + 0.2 * _sig(centre_low, 0.45, 0.75)),
        "explosion": burst_gate * (1.0 * _sig(radial_m, 0.1, 0.45) + 0.7 * longish + 0.5 * warm
                                   + 0.4 * _sig(smoke_ratio, 0.1, 0.6) + 0.3 * _sig(area_peak, 0.05, 0.2)),
        "aura": 1.2 * _sig(held, 0.6, 1.5) + 0.5 * _sig(upward_m, 0.1, 0.5)
        + 0.4 * (1 - _sig(travel, 0.1, 0.3)) * _sig(held, 0.3, 0.8) + 0.2 * longish,
        "beam": 1.3 * _sig(elong_peak, 3.0, 6.0) * _sig(held, 0.35, 0.9) + 0.4 * (1 - _sig(swirl_m, 0.2, 0.5)) * linear
        * _sig(held, 0.25, 0.6) + 0.2 * longish,
        "lightning": 1.1 * _sig(flicker, 0.45, 1.0) + 0.5 * _sig(white_ratio, 0.15, 0.5) * linear
        + 0.3 * (cold + purple > 0) + 0.2 * _sig(elong_peak, 1.8, 3.5),
        "projectile": 1.4 * _sig(travel, 0.2, 0.5) + 0.3 * (1 - _sig(area_peak, 0.05, 0.2)),
        "fire": 1.0 * warm + 0.6 * _sig(upward_m, 0.1, 0.5) + 0.4 * _sig(held, 0.4, 1.0)
        + 0.3 * _sig(flicker, 0.2, 0.6) - 0.3 * gold,
        "ice": 1.0 * cold * _sig(1 - ps, 0.2, 0.6) + 0.5 * cold * round_ + 0.3 * _sig(radial_m, 0.0, 0.3) * round_,
        "dark": 1.1 * purple + 0.5 * _sig(swirl_m, 0.2, 0.5) + 0.4 * _sig(-radial_m, 0.0, 0.3)
        + 0.3 * _sig(smoke_ratio, 0.2, 0.8),
        "holy": 1.0 * gold + 0.5 * pale + 0.4 * _sig(white_ratio, 0.3, 0.7) + 0.3 * _sig(radial_m, 0.0, 0.3) * round_,
    }
    style = (options.get("style") or "auto").lower()
    if style in scores:
        archetype = style
    else:
        archetype = max(scores, key=scores.get)
    ordered = sorted(scores.values(), reverse=True)
    confidence = round(float(max(0.0, min(1.0, 0.5 + (ordered[0] - ordered[1]) / 1.5))), 2)

    base, nominal, desc = ARCHETYPES[archetype]
    scale = float(np.clip(0.7 + 2.2 * math.sqrt(max(area_peak, 0.0)), 0.7, 1.9))
    if options.get("scale"):
        scale = float(options["scale"])
    speed = float(np.clip(nominal / max(total, 0.15), 0.6, 1.6))
    if options.get("speed"):
        speed = float(options["speed"])
    roll = 0.0
    if archetype == "slash":
        roll = float(((angle_peak + 90) % 180) - 90)    # image angle of the swipe, -90..90
    yaw = 0.0
    if archetype in ("beam", "projectile"):
        dx = cx[end] - cx[onset]
        yaw = 0.0 if dx >= 0 else 180.0

    parts = [{"base": base, "t": 0.0, "at": [0, 0, 0], "scale": 1.0}]
    if len(beats) >= 2 and archetype in ("slash", "projectile", "beam", "lightning", "aura"):
        last = beats[-1]
        if radial[last] > 0.15 and (last - beats[0]) / fps > 0.12:
            follow = "explosion" if warm else "impact"
            parts.append({"base": follow, "t": round((last - beats[0]) / fps / speed, 3),
                          "at": [0, 0, -6] if archetype != "aura" else [0, 0, 0], "scale": 0.85})

    result = {
        "type": "vfx",
        "version": 1,
        "base": base,
        "archetype": archetype,
        "description": desc,
        "palette": palette,
        "scale": round(scale, 3),
        "speed": round(speed, 3),
        "intensity": round(float(np.clip(0.8 + vividness, 0.8, 1.4)), 3),
        "roll": round(roll, 1),
        "yaw": round(yaw, 1),
        "parts": parts,
        "analysis": {
            "confidence": confidence,
            "scores": {k: round(float(v), 3) for k, v in sorted(scores.items(), key=lambda kv: -kv[1])},
            "timing": {"onset": round((start + onset) / fps, 3), "peak": round((start + peak) / fps, 3),
                       "end": round((start + end) / fps, 3), "attack": round(attack, 3), "decay": round(decay, 3),
                       "total": round(total, 3), "beats": len(beats)},
            "features": {"radial": round(radial_m, 3), "swirl": round(swirl_m, 3), "upward": round(upward_m, 3),
                         "elongation": round(elong_peak, 2), "travel": round(travel, 3),
                         "areaPeak": round(area_peak, 4), "whiteRatio": round(white_ratio, 3),
                         "flicker": round(flicker, 3), "sustain": round(sustain, 3), "smoke": round(smoke_ratio, 3),
                         "motionSpeed": round(speed_m, 3), "hue": round(hue, 1), "vividness": round(vividness, 3)},
        },
    }
    if sheet_path:
        try:
            _contact_sheet(frames, onset, peak, end, palette, sheet_path)
            result["sheet"] = os.path.basename(sheet_path)
        except Exception:  # the sheet is a nicety, never fail the job for it
            pass
    if progress:
        progress(1.0, f"Looks like a {desc} ({int(confidence * 100)}% sure)")
    return result


def _contact_sheet(frames, onset, peak, end, palette, path):
    import cv2
    idx = sorted(set([onset, (onset + peak) // 2, peak, min(end, peak + max(1, (end - peak) // 3)),
                      min(end, peak + max(2, 2 * (end - peak) // 3)), end]))
    tiles = [frames[i] for i in idx]
    h = tiles[0].shape[0]
    strip = np.concatenate(tiles, axis=1)
    bar = np.zeros((28, strip.shape[1], 3), np.uint8)
    cols = [palette[k] for k in ("core", "primary", "secondary", "deep")]
    wseg = strip.shape[1] // len(cols)
    for i, c in enumerate(cols):
        r, g, b = int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)
        bar[:, i * wseg:(i + 1) * wseg] = (b, g, r)
    sheet = np.concatenate([strip, bar], axis=0)
    cv2.imwrite(path, sheet, [int(cv2.IMWRITE_JPEG_QUALITY), 88])
    return h
