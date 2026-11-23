"""Synthetic edit -> analyze_cutscene: a fade in, a locked-off shot, a hard cut to a push in, a hard cut to a pan with a
white flash in it, should read as three shots (locked off, push in, orbit), a fade at the start and one flash; quoted
lines land on successive shots. Run:  python tests/test_cutscene_video.py"""
import os
import sys
import tempfile

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from clipforge.cutscene_video import analyze_cutscene  # noqa: E402

W, H, FPS = 640, 360, 30


def texture(seed, tint, w=1400, h=800):
    rng = np.random.default_rng(seed)
    base = rng.integers(0, 255, (h // 8, w // 8), dtype=np.uint8)
    base = cv2.resize(base, (w, h), interpolation=cv2.INTER_CUBIC)
    img = cv2.cvtColor(base, cv2.COLOR_GRAY2BGR).astype(np.float32)
    img = img * np.array(tint, np.float32) / 255.0
    for _ in range(60):  # crisp shapes for the tracker
        x, y = int(rng.integers(0, w)), int(rng.integers(0, h))
        cv2.rectangle(img, (x, y), (x + 18, y + 18), tuple(float(c) for c in tint), -1)
    return np.clip(img, 0, 255).astype(np.uint8)


def window(tex, cx, cy, scale=1.0):
    """A W x H view of the texture centred on (cx, cy), zoomed in by `scale`."""
    ww, hh = W / scale, H / scale
    x0, y0 = int(cx - ww / 2), int(cy - hh / 2)
    crop = tex[y0:y0 + int(hh), x0:x0 + int(ww)]
    return cv2.resize(crop, (W, H), interpolation=cv2.INTER_LINEAR)


def make_clip(path):
    a, b, c = texture(1, (255, 140, 90)), texture(2, (80, 120, 255)), texture(3, (90, 255, 120))
    frames = []
    for i in range(45):  # shot 1: locked off, fading in from black over the first frames
        f = window(a, 700, 400).astype(np.float32)
        f *= 0.0 if i < 4 else min(1.0, (i - 4) / 8)
        frames.append(f.astype(np.uint8))
    for i in range(60):  # shot 2: push in 1.0 -> 1.5
        frames.append(window(b, 700, 400, 1.0 + 0.5 * i / 59))
    for i in range(60):  # shot 3: pan right 4 px a frame, with a white flash in the middle
        f = window(c, 380 + 4 * i, 400)
        if i in (30, 31):
            f = cv2.addWeighted(f, 0.15, np.full_like(f, 255), 0.85, 0)
        frames.append(f)
    vw = cv2.VideoWriter(path, cv2.VideoWriter_fourcc(*"mp4v"), FPS, (W, H))
    for f in frames:
        vw.write(f)
    vw.release()


def test_cutscene_from_edit():
    d = tempfile.mkdtemp()
    p = os.path.join(d, "edit.mp4")
    make_clip(p)
    cs = analyze_cutscene(p, {}, who="Hero", name="TestCut", lines=["First line", "Second line"], effect="shockwave")
    a = cs["analysis"]
    moves = [s["move"] for s in a["shots"]]
    assert len(cs["shots"]) == 3, a["shots"]
    assert moves == ["locked off", "push in", "orbit"], moves
    starts = [s["t"] for s in cs["shots"]]
    assert abs(starts[1] - 1.5) < 0.1 and abs(starts[2] - 3.5) < 0.1, starts
    assert cs["shots"][1]["type"] == "push" and cs["shots"][1]["from"] > cs["shots"][1]["to"]
    assert cs["shots"][2]["type"] == "orbit" and cs["shots"][2]["to"] != cs["shots"][2]["from"]
    kinds = [e["type"] for e in cs["events"]]
    assert kinds.count("flash") == 1, cs["events"]
    flash = next(e for e in cs["events"] if e["type"] == "flash")
    assert abs(flash["t"] - 4.5) < 0.1, flash
    fade = next(e for e in cs["events"] if e["type"] == "fade")
    assert fade["t"] == 0 and fade["from"] == 1 and fade["to"] == 0, fade
    lines = [e for e in cs["events"] if e["type"] == "text"]
    assert [l["text"] for l in lines] == ["First line", "Second line"] and lines[1]["t"] >= starts[1], lines
    fx = next(e for e in cs["events"] if e["type"] == "fx")
    assert fx["effect"] == "shockwave" and abs(fx["t"] - 4.5) < 0.1, fx  # on the biggest beat: the flash
    assert all(s["target"] == "Hero" for s in cs["shots"])
    print("shots:", [(s["t"], s["dur"], s["move"], s["size"]) for s in a["shots"]])


if __name__ == "__main__":
    test_cutscene_from_edit()
    print("all cutscene tests passed")
