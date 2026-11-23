"""Synthetic clips -> analyze_vfx: a purple radial burst should read as an impact/explosion-type burst with a purple
palette, a fast cyan arc as a slash, and prompts should parse. Run:  python tests/test_vfx.py"""
import math
import os
import sys
import tempfile

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from clipforge.prompts import config_from_prompt  # noqa: E402
from clipforge.vfx_analyze import analyze_vfx  # noqa: E402


def write(path, frames, fps=30):
    h, w = frames[0].shape[:2]
    vw = cv2.VideoWriter(path, cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    for f in frames:
        vw.write(f)
    vw.release()


def burst_clip(color_bgr=(255, 60, 160)):
    frames = []
    for t in range(60):
        img = np.full((360, 640, 3), (40, 30, 25), np.uint8)
        k = t - 12
        if k >= 0:
            r = int(8 + 230 * (1 - math.exp(-k / 6)))
            a = max(0.0, 1 - k / 30)
            over = img.copy()
            cv2.circle(over, (320, 220), r, color_bgr, max(2, int(18 * a)))
            if k < 4:
                cv2.circle(over, (320, 220), 40 + 10 * k, (255, 255, 255), -1)
            for i in range(14):
                ang = i / 14 * 2 * math.pi
                d = r * 0.8
                cv2.circle(over, (int(320 + d * math.cos(ang)), int(220 + d * math.sin(ang))), 5, color_bgr, -1)
            img = cv2.addWeighted(over, a, img, 1 - a, 0)
        frames.append(img)
    return frames


def slash_clip():
    frames = []
    for t in range(40):
        img = np.full((360, 640, 3), (30, 30, 30), np.uint8)
        k = t - 10
        if 0 <= k < 12:
            a = max(0.0, 1 - k / 12)
            sweep = min(1.0, k / 4)
            over = img.copy()
            cv2.ellipse(over, (320, 200), (260, 60), -20, 200, 200 + 140 * sweep, (255, 230, 80), 14)
            cv2.ellipse(over, (320, 200), (260, 60), -20, 200, 200 + 140 * sweep, (255, 255, 255), 5)
            img = cv2.addWeighted(over, a, img, 1 - a, 0)
        frames.append(img)
    return frames


if __name__ == "__main__":
    tmp = tempfile.mkdtemp()
    p1 = os.path.join(tmp, "burst.mp4")
    write(p1, burst_clip())
    r1 = analyze_vfx(p1, {}, None, os.path.join(tmp, "burst.jpg"))
    print("burst ->", r1["archetype"], r1["palette"], "scale", r1["scale"], "speed", r1["speed"])
    print("   top scores", list(r1["analysis"]["scores"].items())[:3], r1["analysis"]["timing"])
    assert r1["archetype"] in ("impact", "explosion", "dark", "holy"), r1["archetype"]
    hue = cv2.cvtColor(np.uint8([[[int(r1["palette"]["primary"][i:i + 2], 16) for i in (5, 3, 1)]]]),
                       cv2.COLOR_BGR2HSV)[0, 0, 0]
    hue = int(hue) * 2
    assert 260 <= hue <= 340, f"primary should be purple/magenta, hue {hue}"

    p2 = os.path.join(tmp, "slash.mp4")
    write(p2, slash_clip())
    r2 = analyze_vfx(p2, {}, None, None)
    print("slash ->", r2["archetype"], r2["palette"], "roll", r2["roll"])
    print("   top scores", list(r2["analysis"]["scores"].items())[:3], r2["analysis"]["timing"])
    assert r2["archetype"] == "slash", r2["archetype"]

    for prompt, want in [("huge purple lightning slash", "slash"), ("small holy heal", "holy"),
                         ("fast red fireball that explodes", "projectile"), ("dark void portal", "dark"),
                         ("ground slam with blue shockwave", "impact")]:
        c = config_from_prompt(prompt)
        colour = (c['palette'] or {}).get('primary', 'own colours')  # a library effect named outright keeps its design
        print(f"prompt {prompt!r:40} -> {c['archetype']:10} {colour} scale {c['scale']} parts {[p['base'] for p in c['parts']]}")
        assert c["archetype"] == want, (prompt, c["archetype"])
    print("ALL VFX TESTS PASSED")
