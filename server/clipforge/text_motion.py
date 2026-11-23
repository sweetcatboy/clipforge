"""Text -> Roblox animation, no video needed.

A library of hand-keyed moves (attacks, locomotion, emotes) authored the way animators key them:
  * strong key poses with a clear line of action;
  * anticipation before every action (about 2-3x the strike's length), a fast strike, a held contact frame;
  * overshoot and settle on arrivals, cubic in/out easing between holds;
  * overlapping action: forearms, hands, head and feet trail their parents by a few frames;
  * arcs from interpolating joint rotations, flat feet on planted legs, breathing in holds.
Each move is baked at 30 fps into the same rig-independent data the video pipeline produces (every part's
orientation in character space plus root motion in leg lengths), so the Studio plugin bakes it onto any R15 or R6 rig,
keeps the feet on the ground, and exposes a "Hit" marker that effects and abilities can fire on.

Pose vocabulary (degrees; character faces -Z):
  hips  : pitch (+ leans forward), yaw (+ turns left), roll (+ leans left), fwd / right (travel, leg lengths), air
  chest : bend (+ forward), turn (+ left, i.e. the right shoulder comes forward), side (+ lean left)
  head  : nod (+ down), turn (+ left), tilt (+ left)
  ra/la : lift (0 down, 90 level, 180 straight up; negative swings back), swing (0 forward, + out to its side,
          - across the body), bend (elbow), twist (about the arm), wrist
  rl/ll : lift (+ thigh forward, - back), swing (+ out), knee (bend), ankle ("flat" by default: stays level)
"""
from __future__ import annotations

import math
import re

import numpy as np

from .motion import R15_PARTS, mats_to_quats, quat_continuity, reduce_keys, slerp

FPS = 30

# ---------------------------------------------------------------------------------------------------- maths helpers
def _rx(d):
    a = math.radians(d)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], dtype=float)


def _ry(d):
    a = math.radians(d)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=float)


def _rz(d):
    a = math.radians(d)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=float)


def _axis_angle(axis, d):
    k = np.asarray(axis, dtype=float)
    k = k / np.linalg.norm(k)
    a = math.radians(d)
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(a) * K + (1 - math.cos(a)) * (K @ K)


def _back_out(u, s=1.70158):
    u -= 1
    return u * u * ((s + 1) * u + s) + 1


EASE = {
    "linear": lambda u: u,
    "sine": lambda u: 0.5 - 0.5 * math.cos(math.pi * u),                       # gentle in-out (holds, cycles)
    "inout": lambda u: 4 * u ** 3 if u < 0.5 else 1 - (-2 * u + 2) ** 3 / 2,   # cubic in-out (pose to pose)
    "in": lambda u: u ** 3,                                                     # accelerating (falls, wind-ups)
    "out": lambda u: 1 - (1 - u) ** 3,                                          # decelerating (arrivals)
    "quadin": lambda u: u * u,
    "quadout": lambda u: 1 - (1 - u) ** 2,
    "snap": lambda u: 1 - (1 - u) ** 3.5,                                       # strikes: fast out, the arc still reads
    "back": _back_out,                                                          # overshoot, then settle
    "settle": lambda u: _back_out(0.5 - 0.5 * math.cos(math.pi * u), 1.2),     # gentle start, small overshoot (gestures)
    "hold": lambda u: 0.0,                                                      # see _resolve_holds
}

JOINTS = ["hips", "chest", "head", "rua", "rla", "rh", "lua", "lla", "lh", "rul", "rll", "rf", "lul", "lll", "lf"]
PART = {"hips": "LowerTorso", "chest": "UpperTorso", "head": "Head",
        "rua": "RightUpperArm", "rla": "RightLowerArm", "rh": "RightHand",
        "lua": "LeftUpperArm", "lla": "LeftLowerArm", "lh": "LeftHand",
        "rul": "RightUpperLeg", "rll": "RightLowerLeg", "rf": "RightFoot",
        "lul": "LeftUpperLeg", "lll": "LeftLowerLeg", "lf": "LeftFoot"}
PARENT = {"chest": "hips", "head": "chest", "rua": "chest", "rla": "rua", "rh": "rla", "lua": "chest", "lla": "lua",
          "lh": "lla", "rul": "hips", "rll": "rul", "rf": "rll", "lul": "hips", "lll": "lul", "lf": "lll"}
# overlapping action: how far (seconds) each joint trails the pose timing
LAG = {"hips": 0.0, "chest": 0.017, "head": 0.05, "rua": 0.008, "rla": 0.033, "rh": 0.066, "lua": 0.008, "lla": 0.033,
       "lh": 0.066, "rul": 0.0, "rll": 0.008, "rf": 0.03, "lul": 0.0, "lll": 0.008, "lf": 0.03}
MIRROR_KEY = {"ra": "la", "la": "ra", "rl": "ll", "ll": "rl"}
NEGATE = {"hips": ("yaw", "roll", "right"), "chest": ("turn", "side"), "head": ("turn", "tilt")}


def _limb_axis(swing, side):
    s = math.radians(swing)
    return np.array([math.cos(s), 0.0, (1 if side == "r" else -1) * math.sin(s)])


def _locals(pose):
    """Pose -> local rotation matrix per joint, plus root travel (fwd, right, air) in leg lengths."""
    h, c, hd = pose.get("hips", {}), pose.get("chest", {}), pose.get("head", {})
    pitch = h.get("pitch", 0.0)
    L = {"hips": _ry(h.get("yaw", 0)) @ _rx(-pitch) @ _rz(h.get("roll", 0)),
         "chest": _ry(c.get("turn", 0)) @ _rx(-c.get("bend", 0)) @ _rz(c.get("side", 0)),
         "head": _ry(hd.get("turn", 0)) @ _rx(-hd.get("nod", 0)) @ _rz(hd.get("tilt", 0))}
    for side in ("r", "l"):
        sgn = 1 if side == "r" else -1
        a = pose.get(side + "a", {})
        L[side + "ua"] = _axis_angle(_limb_axis(a.get("swing", 0), side), a.get("lift", 0)) @ _ry(sgn * a.get("twist", 0))
        L[side + "la"] = _rx(max(0.0, a.get("bend", 0)))
        L[side + "h"] = _rx(a.get("wrist", 0)) @ _rz(sgn * a.get("dev", 0))
        g = pose.get(side + "l", {})
        raise_, knee = g.get("lift", 0), max(0.0, g.get("knee", 0))
        ankle = g.get("ankle", "flat")
        if ankle == "flat":  # keep the sole level: undo the pelvis pitch, the thigh and the shin
            ankle = pitch - raise_ + knee
        L[side + "ul"] = _axis_angle(_limb_axis(g.get("swing", 0), side), raise_) @ _ry(sgn * g.get("twist", 0))
        L[side + "ll"] = _rx(-knee)
        L[side + "f"] = _rx(ankle)
    travel = np.array([h.get("fwd", 0.0), h.get("right", 0.0), h.get("air", 0.0)])
    return L, travel


def _quat_from_mat(m):
    return mats_to_quats(m[None])[0]


def _mat_from_quat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


# --------------------------------------------------------------------------------------------------------- stances
def _pose(**kw):
    return kw


RELAXED = _pose(hips={}, chest={"bend": 3}, head={"nod": 2},
                ra={"lift": 8, "swing": 12, "bend": 14, "wrist": 4}, la={"lift": 8, "swing": 12, "bend": 14, "wrist": 4},
                rl={"swing": 4, "knee": 5}, ll={"swing": 4, "knee": 5})
# orthodox guard: bladed to the right, left foot and hand lead, chin tucked, weight low
FIGHT = _pose(hips={"yaw": -24, "pitch": 6}, chest={"turn": 16, "bend": 6}, head={"turn": 8, "nod": 6},
              la={"lift": 42, "swing": -12, "bend": 112, "twist": 12, "wrist": 8},
              ra={"lift": 32, "swing": -26, "bend": 128, "twist": 12, "wrist": 8},
              ll={"lift": 15, "swing": 8, "knee": 20}, rl={"lift": -13, "swing": 10, "knee": 24})
# one-handed blade held low and ready
BLADE = _pose(hips={"yaw": -10, "pitch": 5}, chest={"turn": 8, "bend": 5}, head={"turn": 6, "nod": 3},
              ra={"lift": 28, "swing": 14, "bend": 32, "twist": -10, "wrist": -10},
              la={"lift": 22, "swing": -8, "bend": 60, "wrist": 6},
              ll={"lift": 12, "swing": 8, "knee": 16}, rl={"lift": -10, "swing": 10, "knee": 18})
STANCES = {"relaxed": RELAXED, "fight": FIGHT, "blade": BLADE}


def _merge(base, over, power=1.0):
    """Key pose = stance + overrides; power exaggerates every change away from the stance."""
    out = {}
    for part in set(base) | set(over):
        b = dict(base.get(part, {}))
        o = over.get(part, {})
        for k, v in o.items():
            if isinstance(v, (int, float)) and k not in ("fwd", "right", "air"):
                v = b.get(k, 0) + (v - b.get(k, 0)) * power if isinstance(b.get(k, 0), (int, float)) else v
            b[k] = v
        out[part] = b
    for limb in ("ra", "la"):
        if limb in out:
            out[limb]["bend"] = float(np.clip(out[limb].get("bend", 0), 0, 155))
    for limb in ("rl", "ll"):
        if limb in out:
            out[limb]["knee"] = float(np.clip(out[limb].get("knee", 0), 0, 150))
    return out


def _mirror_pose(p):
    out = {}
    for part, spec in p.items():
        spec = dict(spec)
        for k in NEGATE.get(part, ()):
            if k in spec and isinstance(spec[k], (int, float)):
                spec[k] = -spec[k]
        out[MIRROR_KEY.get(part, part)] = spec
    return out


# ------------------------------------------------------------------------------------------------------------ moves
# key = (time s, pose overrides on the stance, easing INTO this key)
def K(t, ease="inout", shake=0.0, **pose):
    return {"t": t, "pose": pose, "ease": ease, "shake": shake}


A = dict  # readability: A(lift=.., swing=..)

MOVES: dict[str, dict] = {}


def move(mid, title, category, tags, stance, keys, hit=(), loop=False, lag=1.0, breath=0.0, travel=False, blurb=""):
    MOVES[mid] = {"id": mid, "title": title, "category": category, "tags": tags, "stance": stance, "keys": keys,
                  "hit": list(hit), "loop": loop, "lag": lag, "breath": breath, "travel": travel, "blurb": blurb}


# --- locomotion & idles ------------------------------------------------------------------------------------------------
move("idle", "Idle", "idle", "idle stand standing breathe breathing rest wait", "relaxed", [
    K(0.0),
    K(1.5, "sine", hips={"roll": 1.2, "right": -0.015}, chest={"bend": 1.5}, head={"nod": 1},
      ra=A(lift=9.5), la=A(lift=9.5)),
    K(3.0, "sine"),
], loop=True, breath=0.0, blurb="Relaxed standing with breathing and a slow weight shift")

move("fightidle", "Fighting Idle", "idle", "fighting stance guard combat idle boxing ready fight battle", "fight", [
    K(0.0),
    K(0.3, "sine", rl=A(knee=30), ll=A(knee=26), ra=A(lift=30), la=A(lift=40), head={"nod": 8}),
    K(0.6, "sine"),
    K(0.9, "sine", rl=A(knee=30), ll=A(knee=26), ra=A(lift=30), la=A(lift=40), head={"nod": 8}),
    K(1.2, "sine"),
], loop=True, blurb="Bouncing boxer's guard")

_walk_r = dict(hips={"yaw": 6, "roll": -2}, chest={"turn": -7, "bend": 4},
               rl=A(lift=24, knee=4, ankle=14), ll=A(lift=-18, knee=8, ankle=-14),
               ra=A(lift=-16, swing=10, bend=10), la=A(lift=22, swing=4, bend=26))
_walk_pass_l = dict(hips={"roll": 2}, rl=A(lift=2, knee=10), ll=A(lift=14, knee=48, ankle=-8),
                    ra=A(lift=4, bend=16), la=A(lift=4, bend=16))
move("walk", "Walk", "locomotion", "walk walking stroll step steps", "relaxed", [
    K(0.0, **_walk_r),
    K(0.25, "sine", **_walk_pass_l),
    K(0.5, "sine", **_mirror_pose(_walk_r)),
    K(0.75, "sine", **_mirror_pose(_walk_pass_l)),
    K(1.0, "sine", **_walk_r),
], loop=True, blurb="Relaxed walk cycle (in place)")

_run_r = dict(hips={"pitch": 12, "yaw": 9, "air": 0.0}, chest={"turn": -12, "bend": 8}, head={"nod": -4},
              rl=A(lift=30, knee=18, ankle=10), ll=A(lift=-32, knee=42, ankle=-25),
              ra=A(lift=-42, swing=12, bend=78), la=A(lift=52, swing=-14, bend=96))
_run_flight_l = dict(hips={"pitch": 12, "air": 0.07}, chest={"bend": 8}, head={"nod": -4},
                     rl=A(lift=-12, knee=30, ankle=-18), ll=A(lift=48, knee=100, ankle=-10),
                     ra=A(lift=6, bend=85), la=A(lift=6, bend=85))
move("run", "Run", "locomotion", "run running jog jogging", "relaxed", [
    K(0.0, **_run_r),
    K(0.165, "sine", **_run_flight_l),
    K(0.33, "sine", **_mirror_pose(_run_r)),
    K(0.495, "sine", **_mirror_pose(_run_flight_l)),
    K(0.66, "sine", **_run_r),
], loop=True, blurb="Run cycle with lean and flight phase (in place)")

_spr_r = dict(hips={"pitch": 20, "yaw": 10}, chest={"turn": -14, "bend": 14}, head={"nod": -10},
              rl=A(lift=40, knee=24, ankle=6), ll=A(lift=-40, knee=50, ankle=-30),
              ra=A(lift=-55, swing=10, bend=70), la=A(lift=70, swing=-14, bend=100))
_spr_flight_l = dict(hips={"pitch": 20, "air": 0.1}, chest={"bend": 14}, head={"nod": -10},
                     rl=A(lift=-20, knee=40, ankle=-22), ll=A(lift=62, knee=110, ankle=-6),
                     ra=A(lift=8, bend=85), la=A(lift=8, bend=85))
move("sprint", "Sprint", "locomotion", "sprint sprinting dash fast run rush", "relaxed", [
    K(0.0, **_spr_r),
    K(0.125, "sine", **_spr_flight_l),
    K(0.25, "sine", **_mirror_pose(_spr_r)),
    K(0.375, "sine", **_mirror_pose(_spr_flight_l)),
    K(0.5, "sine", **_spr_r),
], loop=True, blurb="Full-speed sprint with a strong lean (in place)")

move("jump", "Jump", "locomotion", "jump jumping leap hop", "relaxed", [
    K(0.0),
    K(0.16, "out", hips={"pitch": 22}, chest={"bend": 12}, head={"nod": -6},
      rl=A(lift=38, knee=62), ll=A(lift=38, knee=62), ra=A(lift=-38, swing=14, bend=22), la=A(lift=-38, swing=14, bend=22)),
    K(0.28, "snap", hips={"pitch": -4, "air": 0.25}, chest={"bend": -8}, head={"nod": -10},
      rl=A(lift=4, knee=2, ankle=-28), ll=A(lift=4, knee=2, ankle=-28),
      ra=A(lift=150, swing=18, bend=24), la=A(lift=150, swing=18, bend=24)),
    K(0.52, "quadout", hips={"pitch": 6, "air": 1.0}, chest={"bend": 4}, head={"nod": 2},
      rl=A(lift=34, knee=58, ankle=-12), ll=A(lift=30, knee=48, ankle=-12),
      ra=A(lift=118, swing=26, bend=34), la=A(lift=118, swing=26, bend=34)),
    K(0.76, "quadin", hips={"pitch": 4, "air": 0.06}, rl=A(lift=10, knee=12, ankle=-10), ll=A(lift=10, knee=12, ankle=-10),
      ra=A(lift=70, swing=24, bend=30), la=A(lift=70, swing=24, bend=30)),
    K(0.84, "out", hips={"pitch": 20, "air": 0.0}, chest={"bend": 14}, head={"nod": 4},
      rl=A(lift=40, knee=64), ll=A(lift=40, knee=64), ra=A(lift=40, swing=22, bend=28), la=A(lift=40, swing=22, bend=28)),
    K(1.1, "inout"),
], hit=(0.84,), blurb="Crouch, launch, tuck at the apex, absorb the landing")

move("backflip", "Backflip", "locomotion", "backflip back flip flip somersault acrobatic tuck", "relaxed", [
    K(0.0),
    K(0.16, "out", hips={"pitch": 18}, chest={"bend": 10}, rl=A(lift=36, knee=60), ll=A(lift=36, knee=60),
      ra=A(lift=-40, swing=14, bend=20), la=A(lift=-40, swing=14, bend=20)),
    K(0.28, "snap", hips={"pitch": -30, "air": 0.45}, chest={"bend": -16}, head={"nod": -24},
      rl=A(lift=0, knee=4, ankle=-28), ll=A(lift=0, knee=4, ankle=-28), ra=A(lift=165, swing=20, bend=16), la=A(lift=165, swing=20, bend=16)),
    K(0.42, "linear", hips={"pitch": -140, "air": 1.15}, chest={"bend": 20}, head={"nod": 20},
      rl=A(lift=110, knee=130), ll=A(lift=110, knee=130), ra=A(lift=70, swing=-30, bend=110), la=A(lift=70, swing=-30, bend=110)),
    K(0.56, "linear", hips={"pitch": -250, "air": 1.0}, chest={"bend": 20}, head={"nod": 20},
      rl=A(lift=110, knee=130), ll=A(lift=110, knee=130), ra=A(lift=70, swing=-30, bend=110), la=A(lift=70, swing=-30, bend=110)),
    K(0.7, "out", hips={"pitch": -345, "air": 0.25}, chest={"bend": 6}, head={"nod": 4},
      rl=A(lift=30, knee=40, ankle=-12), ll=A(lift=30, knee=40, ankle=-12), ra=A(lift=110, swing=40, bend=24), la=A(lift=110, swing=40, bend=24)),
    K(0.8, "in", hips={"pitch": -342, "air": 0.0}, chest={"bend": 14},
      rl=A(lift=44, knee=66), ll=A(lift=44, knee=66), ra=A(lift=60, swing=40, bend=30), la=A(lift=60, swing=40, bend=30)),
    K(1.15, "inout", hips={"pitch": -360}),
], hit=(0.8,), lag=0.8, blurb="Crouch, launch, tucked back somersault, land")

move("frontflip", "Front Flip", "locomotion", "front flip frontflip forward flip somersault", "relaxed", [
    K(0.0),
    K(0.16, "out", hips={"pitch": 22}, chest={"bend": 12}, rl=A(lift=38, knee=62), ll=A(lift=38, knee=62),
      ra=A(lift=-40, swing=14, bend=20), la=A(lift=-40, swing=14, bend=20)),
    K(0.3, "snap", hips={"pitch": 50, "air": 0.5, "fwd": 0.15}, chest={"bend": 26}, head={"nod": 30},
      rl=A(lift=20, knee=20, ankle=-28), ll=A(lift=20, knee=20, ankle=-28), ra=A(lift=120, swing=10, bend=30), la=A(lift=120, swing=10, bend=30)),
    K(0.44, "linear", hips={"pitch": 160, "air": 1.1, "fwd": 0.4}, chest={"bend": 30}, head={"nod": 30},
      rl=A(lift=110, knee=130), ll=A(lift=110, knee=130), ra=A(lift=60, swing=-30, bend=110), la=A(lift=60, swing=-30, bend=110)),
    K(0.58, "linear", hips={"pitch": 270, "air": 0.9, "fwd": 0.65}, chest={"bend": 30}, head={"nod": 30},
      rl=A(lift=110, knee=130), ll=A(lift=110, knee=130), ra=A(lift=60, swing=-30, bend=110), la=A(lift=60, swing=-30, bend=110)),
    K(0.72, "out", hips={"pitch": 345, "air": 0.2, "fwd": 0.85}, chest={"bend": 10},
      rl=A(lift=30, knee=40, ankle=-12), ll=A(lift=30, knee=40, ankle=-12), ra=A(lift=100, swing=40, bend=24), la=A(lift=100, swing=40, bend=24)),
    K(0.82, "in", hips={"pitch": 352, "air": 0.0, "fwd": 0.9}, chest={"bend": 16},
      rl=A(lift=44, knee=66), ll=A(lift=44, knee=66), ra=A(lift=50, swing=40, bend=30), la=A(lift=50, swing=40, bend=30)),
    K(1.15, "inout", hips={"pitch": 360, "fwd": 0.9}),
], hit=(0.82,), lag=0.8, travel=True, blurb="Forward somersault landing a step ahead")

move("dash", "Dash", "locomotion", "dash dodge lunge burst rush forward step", "relaxed", [
    K(0.0),
    K(0.08, "out", hips={"pitch": 12}, rl=A(lift=20, knee=30), ll=A(lift=20, knee=30)),
    K(0.2, "snap", hips={"pitch": 26, "fwd": 1.6}, chest={"bend": 14}, head={"nod": -12},
      rl=A(lift=42, knee=56), ll=A(lift=-38, knee=36),
      ra=A(lift=-58, swing=16, bend=18), la=A(lift=-58, swing=16, bend=18)),
    K(0.32, "out", hips={"pitch": 18, "fwd": 1.75}, rl=A(lift=34, knee=46), ll=A(lift=-24, knee=30),
      ra=A(lift=-40, bend=24), la=A(lift=-40, bend=24)),
    K(0.55, "inout", hips={"fwd": 1.75}),
], travel=True, hit=(0.2,), blurb="Explosive forward dash with arms swept back")

move("roll", "Dodge Roll", "locomotion", "roll dodge forward roll tumble evade", "relaxed", [
    K(0.0),
    K(0.1, "out", hips={"pitch": 35, "fwd": 0.1}, chest={"bend": 25}, head={"nod": 25},
      rl=A(lift=60, knee=80), ll=A(lift=60, knee=80), ra=A(lift=50, swing=-30, bend=90), la=A(lift=50, swing=-30, bend=90)),
    K(0.24, "linear", hips={"pitch": 125, "fwd": 0.55}, chest={"bend": 35}, head={"nod": 35},
      rl=A(lift=110, knee=130), ll=A(lift=110, knee=130), ra=A(lift=60, swing=-40, bend=120), la=A(lift=60, swing=-40, bend=120)),
    K(0.38, "linear", hips={"pitch": 235, "fwd": 1.0}, chest={"bend": 35}, head={"nod": 35},
      rl=A(lift=110, knee=130), ll=A(lift=110, knee=130), ra=A(lift=60, swing=-40, bend=120), la=A(lift=60, swing=-40, bend=120)),
    K(0.52, "out", hips={"pitch": 345, "fwd": 1.35}, chest={"bend": 20}, head={"nod": 10},
      rl=A(lift=70, knee=110), ll=A(lift=60, knee=90), ra=A(lift=40, swing=20, bend=40), la=A(lift=40, swing=20, bend=40)),
    K(0.8, "inout", hips={"pitch": 360, "fwd": 1.45}),
], travel=True, hit=(0.52,), blurb="Tucked forward roll back onto your feet")

# --- strikes ---------------------------------------------------------------------------------------------------------
move("jab", "Jab", "combat", "jab quick straight lead left", "fight", [
    K(0.0),
    K(0.06, "out", chest={"turn": 22}, la=A(lift=38, bend=122)),
    K(0.12, "snap", hips={"yaw": -30, "fwd": 0.04}, chest={"turn": -8}, head={"turn": 18},
      la=A(lift=94, swing=14, bend=12, twist=-71, wrist=0), ll=A(lift=18, knee=22)),
    K(0.18, "hold"),
    K(0.32, "inout"),
    K(0.42, "inout"),
], hit=(0.12,), lag=0.5, blurb="Snapping lead-hand jab")

move("cross", "Cross", "combat", "cross punch straight right punch power punch", "fight", [
    K(0.0),
    K(0.09, "out", hips={"yaw": -34}, chest={"turn": 4}, rl=A(knee=30), ra=A(lift=28, bend=132)),
    K(0.16, "snap", hips={"yaw": 12, "fwd": 0.08, "pitch": 10}, chest={"turn": 30, "bend": 10}, head={"turn": -2},
      ra=A(lift=102, swing=8, bend=20, twist=-73, wrist=0), rl=A(lift=-16, knee=14, ankle=-24, twist=-30),
      ll=A(lift=20, knee=26), la=A(lift=50, swing=-20, bend=125)),
    K(0.23, "hold"),
    K(0.4, "inout"),
    K(0.52, "inout"),
], hit=(0.16,), lag=0.5, blurb="Rear straight with the hips turned through")

move("hook", "Hook", "combat", "hook punch left hook swing punch", "fight", [
    K(0.0),
    K(0.1, "out", hips={"yaw": -14}, chest={"turn": 30}, la=A(lift=92, swing=55, bend=97, twist=24)),
    K(0.19, "snap", hips={"yaw": -44}, chest={"turn": -26, "side": -6}, head={"turn": 22},
      la=A(lift=89, swing=103, bend=108, twist=-27), ll=A(lift=14, knee=28, twist=30)),
    K(0.26, "hold"),
    K(0.43, "inout"),
    K(0.56, "inout"),
], hit=(0.19,), lag=0.5, blurb="Lead hook whipped across with the hips")

move("uppercut", "Uppercut", "combat", "uppercut rising punch launcher upper", "fight", [
    K(0.0),
    K(0.13, "out", hips={"yaw": -30, "pitch": 16}, chest={"turn": -6, "bend": 18}, head={"nod": 4},
      ra=A(lift=49, swing=-12, bend=113, twist=43), rl=A(knee=40), ll=A(knee=36)),
    K(0.22, "snap", hips={"yaw": 10, "pitch": -6, "air": 0.06}, chest={"turn": 26, "bend": -12}, head={"nod": -16},
      ra=A(lift=65, swing=-3, bend=79, twist=-6), rl=A(lift=-6, knee=8, ankle=-22), ll=A(lift=10, knee=10)),
    K(0.29, "hold"),
    K(0.46, "inout"),
    K(0.6, "inout"),
], hit=(0.22,), lag=0.5, blurb="Drop, drive up through the legs, fist to the sky")

move("kick", "Front Kick", "combat", "kick front kick push kick teep", "fight", [
    K(0.0),
    K(0.13, "out", hips={"pitch": -6}, chest={"bend": -6}, rl=A(lift=78, knee=98)),
    K(0.22, "snap", hips={"pitch": -16, "fwd": 0.04}, chest={"bend": -12}, head={"nod": 10},
      rl=A(lift=84, knee=4, ankle=-18), ll=A(lift=4, knee=14), la=A(lift=36, swing=26, bend=90)),
    K(0.3, "hold"),
    K(0.42, "inout", rl=A(lift=74, knee=96)),
    K(0.56, "inout", rl=A(lift=-6, knee=20)),
    K(0.72, "inout"),
], hit=(0.22,), lag=0.6, blurb="Chambered front kick, snap, re-chamber")

move("roundhouse", "Roundhouse Kick", "combat", "roundhouse kick side kick spinning kick roundhouse", "fight", [
    K(0.0),
    K(0.15, "out", hips={"yaw": 40, "roll": 8}, rl=A(lift=60, swing=40, knee=104), chest={"turn": -20}),
    K(0.27, "snap", hips={"yaw": 82, "roll": 22, "pitch": -4}, chest={"turn": -36, "side": 14}, head={"turn": -50},
      rl=A(lift=82, swing=88, knee=6, ankle=-26), ll=A(lift=6, knee=16, twist=60),
      ra=A(lift=24, swing=46, bend=40), la=A(lift=56, swing=-24, bend=110)),
    K(0.36, "hold"),
    K(0.56, "inout", hips={"yaw": 30}, rl=A(lift=40, swing=30, knee=90)),
    K(0.82, "inout"),
], hit=(0.27,), lag=0.6, blurb="Pivoting roundhouse at head height")

# --- weapons ---------------------------------------------------------------------------------------------------------
move("slash", "Sword Slash", "weapon", "slash sword swing cut horizontal slash attack blade katana", "blade", [
    K(0.0),
    K(0.14, "out", hips={"yaw": -24, "pitch": 4}, chest={"turn": -36, "side": -4}, head={"turn": 22, "nod": 2},
      ra=A(lift=94, swing=-12, bend=78, twist=2, wrist=-36), la=A(lift=73, swing=90, bend=55),
      rl=A(lift=-8, knee=24), ll=A(lift=16, knee=22)),
    K(0.24, "snap", hips={"yaw": 18, "pitch": 12, "fwd": 0.18}, chest={"turn": 28, "bend": 12}, head={"turn": -6, "nod": 6},
      ra=A(lift=91, swing=38, bend=4, twist=36, wrist=-69), la=A(lift=15, swing=37, bend=79),
      rl=A(lift=30, knee=30), ll=A(lift=-22, knee=18)),
    K(0.34, "out", hips={"yaw": 28, "pitch": 14, "fwd": 0.2}, chest={"turn": 46, "bend": 16}, head={"turn": -10, "nod": 8},
      ra=A(lift=61, swing=-4, bend=4, twist=82, wrist=-66), la=A(lift=30, swing=-42, bend=95),
      rl=A(lift=32, knee=34), ll=A(lift=-22, knee=22)),
    K(0.44, "sine", hips={"yaw": 26, "pitch": 12, "fwd": 0.2}, chest={"turn": 42, "bend": 14}, head={"turn": -8, "nod": 6},
      ra=A(lift=58, swing=-2, bend=12, twist=76, wrist=-58), la=A(lift=30, swing=-40, bend=92),
      rl=A(lift=30, knee=32), ll=A(lift=-20, knee=20)),
    K(0.66, "inout", hips={"fwd": 0.2}),
], hit=(0.24,), lag=0.55, travel=True, blurb="Sword cocked over the shoulder, diagonal cut with a step, follow-through low")

move("overhead", "Overhead Slam", "weapon", "overhead slam smash two handed greatsword hammer downward chop cleave", "blade", [
    K(0.0),
    K(0.3, "out", hips={"pitch": -6}, chest={"bend": -18, "turn": 0}, head={"nod": -12},
      ra=A(lift=149, swing=-14, bend=10, twist=15, wrist=-15), la=A(lift=131, swing=-30, bend=10, twist=36, wrist=-3),
      rl=A(lift=-6, knee=14), ll=A(lift=14, knee=12)),
    K(0.42, "snap", hips={"pitch": 16, "fwd": 0.16}, chest={"bend": 24}, head={"nod": 10},
      ra=A(lift=90, swing=-28, bend=6, twist=-18, wrist=-66), la=A(lift=92, swing=-61, bend=41, twist=-15, wrist=-63),
      rl=A(lift=-24, knee=26), ll=A(lift=34, knee=46)),
    K(0.56, "hold"),
    K(0.88, "inout", hips={"fwd": 0.16}),
], hit=(0.42,), lag=0.5, travel=True, blurb="Two-handed overhead raise and a heavy downward smash")

move("thrust", "Thrust", "weapon", "thrust stab pierce lunge spear rapier poke", "blade", [
    K(0.0),
    K(0.15, "out", hips={"yaw": -18, "pitch": 2}, chest={"turn": -28}, head={"turn": 12},
      ra=A(lift=55, swing=86, bend=118, twist=25, wrist=-68), la=A(lift=64, swing=63, bend=63), rl=A(knee=20), ll=A(knee=22)),
    K(0.24, "snap", hips={"yaw": 10, "pitch": 14, "fwd": 0.42}, chest={"turn": 18, "bend": 10}, head={"turn": -4},
      ra=A(lift=106, swing=22, bend=0, twist=18, wrist=-75), la=A(lift=41, swing=117, bend=35),
      rl=A(lift=38, knee=44), ll=A(lift=-30, knee=8)),
    K(0.34, "hold"),
    K(0.6, "inout", hips={"fwd": 0.42}),
], hit=(0.24,), lag=0.5, travel=True, blurb="Lunging stab with the arm fully extended")

move("spin", "Spin Attack", "weapon", "spin spinning whirlwind 360 sweep tornado cyclone", "blade", [
    K(0.0),
    K(0.14, "out", hips={"yaw": 30, "pitch": 10}, chest={"turn": 20}, ra=A(lift=86, swing=68, bend=0, twist=-72, wrist=-72), la=A(lift=80, swing=70, bend=20),
      rl=A(knee=34), ll=A(knee=34)),
    K(0.26, "linear", hips={"yaw": -90, "pitch": 10}, chest={"turn": -10}, ra=A(lift=86, swing=68, bend=0, twist=-72, wrist=-72), la=A(lift=80, swing=76, bend=14),
      rl=A(knee=30), ll=A(knee=30)),
    K(0.38, "linear", hips={"yaw": -210, "pitch": 10}, chest={"turn": -10}, ra=A(lift=86, swing=68, bend=0, twist=-72, wrist=-72), la=A(lift=80, swing=76, bend=14),
      rl=A(knee=30), ll=A(knee=30)),
    K(0.5, "out", hips={"yaw": -330, "pitch": 10}, chest={"turn": -14}, ra=A(lift=80, swing=56, bend=8, twist=-60, wrist=-60), la=A(lift=70, swing=60, bend=20),
      rl=A(knee=30), ll=A(knee=30)),
    K(0.78, "inout", hips={"yaw": -360}),
], hit=(0.26, 0.38), lag=0.7, blurb="Full 360 spin with arms out")

# --- powers ----------------------------------------------------------------------------------------------------------
move("cast", "Spell Cast", "magic", "cast spell magic blast fireball throw magic palm push summon conjure", "relaxed", [
    K(0.0),
    K(0.16, "out", hips={"yaw": -10}, chest={"turn": -18, "bend": 4}, ra=A(lift=36, swing=34, bend=96, wrist=20), rl=A(knee=14), ll=A(lift=10, knee=12)),
    K(0.25, "snap", hips={"yaw": 8, "pitch": 6, "fwd": 0.06}, chest={"turn": 12, "bend": 8}, head={"nod": -4},
      ra=A(lift=90, swing=0, bend=0, twist=-60, wrist=-62), la=A(lift=22, swing=26, bend=30)),
    K(0.5, "hold", shake=0.6),
    K(0.75, "inout"),
], hit=(0.25,), lag=0.6, blurb="Draw back, palm thrust forward, hold the cast")

move("charge", "Power Up", "magic", "charge power up powerup aura transform scream rage focus energy saiyan", "relaxed", [
    K(0.0),
    K(0.3, "out", hips={"pitch": 12}, chest={"bend": 10}, head={"nod": 10},
      ra=A(lift=26, swing=44, bend=64, twist=30), la=A(lift=26, swing=44, bend=64, twist=30),
      rl=A(swing=14, knee=36), ll=A(swing=14, knee=36)),
    K(1.1, "linear", shake=1.0, hips={"pitch": 14}, chest={"bend": 14}, head={"nod": 14},
      ra=A(lift=30, swing=48, bend=72, twist=30), la=A(lift=30, swing=48, bend=72, twist=30),
      rl=A(swing=14, knee=40), ll=A(swing=14, knee=40)),
    K(1.22, "snap", hips={"pitch": -6}, chest={"bend": -20}, head={"nod": -22},
      ra=A(lift=128, swing=62, bend=14, twist=10), la=A(lift=128, swing=62, bend=14, twist=10),
      rl=A(swing=16, knee=12), ll=A(swing=16, knee=12)),
    K(1.5, "hold", shake=0.4),
    K(1.85, "inout"),
], hit=(1.22,), lag=0.8, blurb="Crouch and shake building power, then explode upward")

move("beam", "Energy Beam", "magic", "beam kamehameha laser energy wave blast charge fire hands", "relaxed", [
    K(0.0),
    K(0.3, "out", hips={"yaw": -26, "pitch": 6}, chest={"turn": -36, "bend": 6}, head={"turn": 28},
      ra=A(lift=22, swing=-6, bend=108, wrist=40), la=A(lift=30, swing=-48, bend=122, wrist=40),
      rl=A(swing=18, knee=34, lift=-8), ll=A(swing=18, knee=34, lift=14)),
    K(0.95, "linear", shake=0.8, hips={"yaw": -28, "pitch": 8}, chest={"turn": -40, "bend": 8}, head={"turn": 30},
      ra=A(lift=22, swing=-6, bend=112, wrist=40), la=A(lift=30, swing=-50, bend=124, wrist=40),
      rl=A(swing=18, knee=38, lift=-8), ll=A(swing=18, knee=38, lift=14)),
    K(1.05, "snap", hips={"yaw": 6, "pitch": 10, "fwd": 0.08}, chest={"turn": 8, "bend": 10}, head={"turn": -4},
      ra=A(lift=88, swing=-8, bend=0, twist=-80, wrist=-70), la=A(lift=88, swing=-8, bend=0, twist=80, wrist=-70),
      rl=A(swing=18, knee=30, lift=-20), ll=A(swing=18, knee=36, lift=24)),
    K(1.7, "hold", shake=0.7),
    K(2.0, "inout"),
], hit=(1.05,), lag=0.7, blurb="Gather energy at the hip, thrust both palms forward and hold the beam")

move("throw", "Throw", "combat", "throw toss hurl pitch grenade ball overhand", "relaxed", [
    K(0.0),
    K(0.3, "out", hips={"yaw": -30}, chest={"turn": -40, "bend": -10}, head={"turn": 30},
      ra=A(lift=150, swing=62, bend=92, twist=50), la=A(lift=70, swing=-10, bend=20),
      ll=A(lift=26, knee=32), rl=A(knee=18)),
    K(0.42, "snap", hips={"yaw": 18, "pitch": 14, "fwd": 0.12}, chest={"turn": 30, "bend": 24}, head={"turn": -6},
      ra=A(lift=100, swing=-18, bend=10, wrist=40), la=A(lift=20, swing=30, bend=40),
      ll=A(lift=30, knee=28), rl=A(lift=-24, knee=14, ankle=-20)),
    K(0.56, "out", hips={"yaw": 26, "fwd": 0.14}, chest={"turn": 40, "bend": 30}, ra=A(lift=40, swing=-52, bend=30),
      ll=A(lift=30, knee=30), rl=A(lift=-24, knee=16, ankle=-20)),
    K(0.85, "inout", hips={"fwd": 0.14}),
], hit=(0.42,), lag=0.6, travel=True, blurb="Cock behind the head, stride and whip the arm through")

move("groundpound", "Ground Slam", "combat", "ground slam ground pound smash stomp earthquake slam down", "relaxed", [
    K(0.0),
    K(0.16, "out", hips={"pitch": 22}, chest={"bend": 14}, rl=A(lift=36, knee=58), ll=A(lift=36, knee=58),
      ra=A(lift=-40, swing=20, bend=20), la=A(lift=-40, swing=20, bend=20)),
    K(0.42, "quadout", hips={"pitch": -6, "air": 0.8}, chest={"bend": -14}, head={"nod": -12},
      ra=A(lift=172, swing=-8, bend=56), la=A(lift=172, swing=-8, bend=56),
      rl=A(lift=42, knee=78), ll=A(lift=42, knee=78)),
    K(0.6, "in", hips={"pitch": 32, "air": 0.0}, chest={"bend": 52}, head={"nod": 24},
      ra=A(lift=40, swing=-18, bend=14), la=A(lift=40, swing=-18, bend=14),
      rl=A(lift=60, knee=96, swing=18), ll=A(lift=60, knee=96, swing=18)),
    K(0.78, "hold"),
    K(1.15, "inout"),
], hit=(0.6,), lag=0.6, blurb="Leap, fists overhead, smash down into a deep crouch")

move("block", "Block", "combat", "block guard defend parry shield cover", "fight", [
    K(0.0),
    K(0.1, "back", chest={"bend": 12, "turn": 6}, head={"nod": 14},
      ra=A(lift=96, swing=-36, bend=102, twist=30), la=A(lift=100, swing=-32, bend=98, twist=30),
      rl=A(knee=30), ll=A(knee=28)),
    K(0.6, "hold"),
    K(0.8, "inout"),
], hit=(0.1,), lag=0.6, blurb="Snap the forearms up in front of the face")

# --- reactions -------------------------------------------------------------------------------------------------------
move("hitreact", "Hit Reaction", "reaction", "hit react reaction hurt flinch get hit take damage stagger", "relaxed", [
    K(0.0),
    K(0.07, "snap", hips={"pitch": -10, "fwd": -0.16}, chest={"bend": -22, "side": 6}, head={"nod": -26, "tilt": 8},
      ra=A(lift=44, swing=34, bend=52), la=A(lift=38, swing=30, bend=46), rl=A(lift=-10, knee=12), ll=A(lift=12, knee=20)),
    K(0.2, "out", hips={"pitch": -6, "fwd": -0.22}, chest={"bend": -12}, head={"nod": -10}),
    K(0.55, "inout", hips={"fwd": -0.22}),
], hit=(0.07,), lag=1.2, travel=True, blurb="Snap back from a hit and recover")

move("knockdown", "Knockdown", "reaction", "knockdown knocked down fall death die dead defeat ko knock out", "relaxed", [
    K(0.0),
    K(0.08, "snap", hips={"pitch": -14, "fwd": -0.15}, chest={"bend": -26}, head={"nod": -30},
      ra=A(lift=70, swing=40, bend=40), la=A(lift=70, swing=40, bend=40), rl=A(lift=20, knee=20), ll=A(lift=-10, knee=10)),
    K(0.45, "in", hips={"pitch": -60, "fwd": -0.55}, chest={"bend": -10}, head={"nod": -10},
      ra=A(lift=120, swing=60, bend=30), la=A(lift=110, swing=60, bend=30), rl=A(lift=40, knee=30), ll=A(lift=30, knee=20)),
    K(0.62, "out", hips={"pitch": -88, "fwd": -0.8}, chest={"bend": 4}, head={"nod": 6},
      ra=A(lift=100, swing=70, bend=20), la=A(lift=95, swing=75, bend=20), rl=A(lift=14, knee=8), ll=A(lift=24, knee=30)),
    K(0.78, "back", hips={"pitch": -86, "fwd": -0.8}, head={"nod": 0}),
    K(1.6, "hold", hips={"pitch": -86, "fwd": -0.8}, chest={"bend": 4}, head={"nod": 2},
      ra=A(lift=100, swing=70, bend=20), la=A(lift=95, swing=75, bend=20), rl=A(lift=14, knee=8), ll=A(lift=24, knee=30)),
], hit=(0.62,), lag=1.0, travel=True, blurb="Thrown back off your feet onto the ground")

move("stun", "Dizzy", "reaction", "dizzy stunned stun daze dazed woozy confused", "relaxed", [
    K(0.0, hips={"roll": 7}, chest={"side": -9, "bend": 8}, head={"tilt": 14, "nod": 10}, rl=A(knee=16), ll=A(knee=12)),
    K(0.8, "sine", hips={"roll": -7}, chest={"side": 9, "bend": 8}, head={"tilt": -14, "nod": 10}, rl=A(knee=12), ll=A(knee=16)),
    K(1.6, "sine", hips={"roll": 7}, chest={"side": -9, "bend": 8}, head={"tilt": 14, "nod": 10}, rl=A(knee=16), ll=A(knee=12)),
], loop=True, lag=1.5, blurb="Woozy sway, head lolling")

# --- emotes ----------------------------------------------------------------------------------------------------------
move("wave", "Wave", "emote", "wave hello hi greet greeting bye goodbye", "relaxed", [
    K(0.0),
    K(0.3, "settle", chest={"side": 3}, head={"tilt": 6}, ra=A(lift=150, swing=34, bend=32, twist=-20)),
    K(0.55, "sine", ra=A(lift=150, swing=52, bend=40, twist=-20), chest={"side": 3}, head={"tilt": 6}),
    K(0.8, "sine", ra=A(lift=150, swing=22, bend=26, twist=-20), chest={"side": 3}, head={"tilt": 6}),
    K(1.05, "sine", ra=A(lift=150, swing=52, bend=40, twist=-20), chest={"side": 3}, head={"tilt": 6}),
    K(1.3, "sine", ra=A(lift=150, swing=22, bend=26, twist=-20), chest={"side": 3}, head={"tilt": 6}),
    K(1.7, "inout"),
], lag=1.2, blurb="Friendly wave")

move("cheer", "Victory Cheer", "emote", "cheer victory win celebrate yay hooray yes winner triumph", "relaxed", [
    K(0.0),
    K(0.16, "out", hips={"pitch": 12}, rl=A(lift=26, knee=42), ll=A(lift=26, knee=42),
      ra=A(lift=40, swing=30, bend=90), la=A(lift=40, swing=30, bend=90)),
    K(0.3, "snap", hips={"air": 0.35, "pitch": -4}, chest={"bend": -12}, head={"nod": -18},
      ra=A(lift=162, swing=36, bend=8), la=A(lift=162, swing=36, bend=8), rl=A(knee=10, ankle=-24), ll=A(knee=10, ankle=-24)),
    K(0.48, "quadin", hips={"air": 0.0, "pitch": 6}, rl=A(lift=20, knee=30), ll=A(lift=20, knee=30),
      ra=A(lift=158, swing=40, bend=14), la=A(lift=158, swing=40, bend=14), head={"nod": -14}, chest={"bend": -8}),
    K(0.7, "sine", ra=A(lift=150, swing=30, bend=30), la=A(lift=150, swing=30, bend=30), head={"nod": -12}, chest={"bend": -8}),
    K(0.9, "sine", ra=A(lift=162, swing=38, bend=8), la=A(lift=162, swing=38, bend=8), head={"nod": -16}, chest={"bend": -10}),
    K(1.45, "inout"),
], hit=(0.3,), lag=1.0, blurb="Hop with both arms thrown up")

move("dance", "Groove", "emote", "dance dancing groove party vibe boogie club", "relaxed", [
    K(0.0, hips={"roll": 6, "right": 0.05}, chest={"side": -5, "turn": 6}, head={"tilt": -5},
      rl=A(knee=22), ll=A(knee=8), ra=A(lift=48, swing=10, bend=96), la=A(lift=22, swing=20, bend=80)),
    K(0.25, "sine", hips={"pitch": 4}, rl=A(knee=26), ll=A(knee=26), ra=A(lift=36, bend=90), la=A(lift=36, bend=90), head={"nod": 8}),
    K(0.5, "sine", hips={"roll": -6, "right": -0.05}, chest={"side": 5, "turn": -6}, head={"tilt": 5},
      rl=A(knee=8), ll=A(knee=22), ra=A(lift=22, swing=20, bend=80), la=A(lift=48, swing=10, bend=96)),
    K(0.75, "sine", hips={"pitch": 4}, rl=A(knee=26), ll=A(knee=26), ra=A(lift=36, bend=90), la=A(lift=36, bend=90), head={"nod": 8}),
    K(1.0, "sine", hips={"roll": 6, "right": 0.05}, chest={"side": -5, "turn": 6}, head={"tilt": -5},
      rl=A(knee=22), ll=A(knee=8), ra=A(lift=48, swing=10, bend=96), la=A(lift=22, swing=20, bend=80)),
], loop=True, lag=1.3, blurb="Bouncy side-to-side groove")

move("clap", "Clap", "emote", "clap clapping applause applaud", "relaxed", [
    K(0.0),
    K(0.2, "out", ra=A(lift=62, swing=-18, bend=82, twist=60), la=A(lift=62, swing=-18, bend=82, twist=60), chest={"bend": 4}),
    *[K(0.2 + 0.24 * i + d, e, ra=A(lift=62, swing=s, bend=82 if s < -30 else 90, twist=60), la=A(lift=62, swing=s, bend=82 if s < -30 else 90, twist=60),
        chest={"bend": 5})
      for i in range(4) for d, s, e in ((0.12, -42, "snap"), (0.24, -16, "out"))],
    K(1.4, "inout"),
], hit=(0.32, 0.56, 0.8, 1.04), lag=0.8, blurb="Four quick claps")

move("bow", "Bow", "emote", "bow respect greet thank thanks polite", "relaxed", [
    K(0.0),
    K(0.45, "inout", hips={"pitch": 16}, chest={"bend": 34}, head={"nod": 18},
      ra=A(lift=36, swing=-62, bend=104), la=A(lift=-16, swing=-36, bend=96), rl=A(swing=0, knee=4), ll=A(swing=0, knee=4)),
    K(1.0, "hold"),
    K(1.5, "inout"),
], lag=1.1, blurb="Formal bow, hand to the chest")

move("point", "Point", "emote", "point pointing there look that you aim", "relaxed", [
    K(0.0),
    K(0.22, "settle", chest={"turn": 12}, head={"turn": -6, "nod": -2}, ra=A(lift=92, swing=4, bend=0, twist=-40, wrist=-4)),
    K(0.9, "hold"),
    K(1.2, "inout"),
], lag=0.9, blurb="Point straight ahead")

move("salute", "Salute", "emote", "salute military respect soldier", "relaxed", [
    K(0.0),
    K(0.3, "settle", chest={"bend": -3}, head={"nod": -2},
      ra=A(lift=104, swing=64, bend=138, twist=20, wrist=24), rl=A(swing=0, knee=0), ll=A(swing=0, knee=0), la=A(lift=4, swing=4, bend=4)),
    K(1.0, "hold"),
    K(1.3, "inout"),
], lag=0.9, blurb="Crisp military salute")

move("shrug", "Shrug", "emote", "shrug dunno idk whatever unsure confused", "relaxed", [
    K(0.0),
    K(0.25, "settle", chest={"bend": -2}, head={"tilt": 12, "nod": -2},
      ra=A(lift=24, swing=34, bend=94, twist=70, wrist=-10), la=A(lift=24, swing=34, bend=94, twist=70, wrist=-10)),
    K(0.75, "hold"),
    K(1.05, "inout"),
], lag=1.0, blurb="Palms-up shrug with a head tilt")

move("flex", "Flex", "emote", "flex muscles strong strength pose bodybuilder", "relaxed", [
    K(0.0),
    K(0.3, "settle", chest={"bend": -10}, head={"nod": -6},
      ra=A(lift=90, swing=86, bend=124, twist=90), la=A(lift=90, swing=86, bend=124, twist=90),
      rl=A(swing=12, knee=10), ll=A(swing=12, knee=10)),
    K(0.7, "hold", shake=0.5),
    K(1.1, "sine", chest={"bend": -12}, ra=A(lift=94, swing=86, bend=130, twist=90), la=A(lift=94, swing=86, bend=130, twist=90),
      rl=A(swing=12, knee=10), ll=A(swing=12, knee=10)),
    K(1.5, "inout"),
], lag=1.0, blurb="Double-biceps flex")

move("laugh", "Laugh", "emote", "laugh laughing lol haha funny lmao", "relaxed", [
    K(0.0),
    *[K(0.15 + 0.2 * i, "sine", chest={"bend": 22 if i % 2 == 0 else 14}, head={"nod": -10 if i % 2 == 0 else -2},
        hips={"pitch": 6}, ra=A(lift=30, swing=-28, bend=94), la=A(lift=30, swing=-28, bend=94), rl=A(knee=12), ll=A(knee=12))
      for i in range(6)],
    K(1.6, "inout"),
], lag=1.2, blurb="Doubled-over laugh, hands on the belly")

move("victorypose", "Victory Pose", "emote", "victory pose fist pump champion winner triumphant pose", "relaxed", [
    K(0.0),
    K(0.3, "settle", chest={"bend": -7}, head={"nod": -10, "turn": 8},
      ra=A(lift=168, swing=20, bend=12), la=A(lift=22, swing=52, bend=112, twist=40), rl=A(swing=10, knee=4), ll=A(swing=10, knee=4)),
    K(1.4, "hold"),
    K(1.8, "inout"),
], hit=(0.3,), lag=1.0, blurb="Fist to the sky, hand on the hip")

move("sad", "Sad Slump", "emote", "sad defeated slump depressed cry upset lose lost", "relaxed", [
    K(0.0, chest={"bend": 26}, head={"nod": 30}, hips={"pitch": 4}, ra=A(lift=6, swing=4, bend=8), la=A(lift=6, swing=4, bend=8)),
    K(1.5, "sine", chest={"bend": 30}, head={"nod": 34}, hips={"pitch": 5}, ra=A(lift=5, swing=4, bend=6), la=A(lift=5, swing=4, bend=6)),
    K(3.0, "sine", chest={"bend": 26}, head={"nod": 30}, hips={"pitch": 4}, ra=A(lift=6, swing=4, bend=8), la=A(lift=6, swing=4, bend=8)),
], loop=True, lag=1.4, blurb="Shoulders slumped, head down, slow breathing")

# the effect each move calls for by default, and where it plays (Abilities attach points)
MOVE_FX = {
    "jab": ("punch", "LeftHand"), "cross": ("punch", "RightHand"), "hook": ("punch", "LeftHand"),
    "uppercut": ("uppercut", "RightHand"), "kick": ("hitspark", "Front"), "roundhouse": ("critical", "Front"),
    "slash": ("slash", "Front"), "overhead": ("groundpound", "Front"), "thrust": ("thrust", "Front"),
    "spin": ("spinslash", "Root"), "cast": ("spellcast", "RightHand"), "charge": ("aura", "Root"),
    "beam": ("beam", "Front"), "throw": ("projectile", "RightHand"), "groundpound": ("groundpound", "Ground"),
    "block": ("parry", "Front"), "jump": ("landing", "Ground"), "backflip": ("landing", "Ground"),
    "frontflip": ("landing", "Ground"), "dash": ("dash", "Root"), "roll": ("dash", "Root"),
    "hitreact": ("hitspark", "Root"), "knockdown": ("landing", "Ground"), "cheer": ("confetti", "Root"),
    "victorypose": ("levelup", "Root"), "clap": ("pickup", "Front"),
    "punchcombo": ("punch", "RightHand"), "swordcombo": ("slash", "Front"), "kickcombo": ("hitspark", "Front"),
}

# combos: moves in sequence
COMBOS = {
    "punchcombo": ("Punch Combo", "combat", "punch combo one two jab cross hook boxing combination", ["jab", "cross", "hook"]),
    "swordcombo": ("Sword Combo", "weapon", "sword combo slash combo three hit attack chain", ["slash", "thrust", "overhead"]),
    "kickcombo": ("Kick Combo", "combat", "kick combo kicks martial arts", ["kick", "roundhouse"]),
}


# ------------------------------------------------------------------------------------------------------------ baking
def _sample_pose(keys, stance, t, power, lagged=None):
    """Interpolate the pose at time t (per joint, with each joint's own lagged time)."""
    if t <= keys[0]["t"]:
        i = 0
        u = 0.0
    elif t >= keys[-1]["t"]:
        i = len(keys) - 2
        u = 1.0
    else:
        i = max(k for k in range(len(keys) - 1) if keys[k]["t"] <= t)
        a, b = keys[i]["t"], keys[i + 1]["t"]
        u = EASE.get(keys[i + 1]["ease"], EASE["inout"])((t - a) / max(b - a, 1e-6))
    return i, u


def bake(mid: str, *, speed: float = 1.0, power: float = 1.0, mirror: bool = False, loop: bool | None = None,
         name: str | None = None, root_motion: str = "inplace") -> dict:
    """One move (or combo id) -> ClipForge animation data."""
    if mid in COMBOS:
        return bake_sequence(COMBOS[mid][3], speed=speed, power=power, mirror=mirror, name=name or COMBOS[mid][0].replace(" ", ""),
                             root_motion=root_motion, title=COMBOS[mid][0])
    m = MOVES[mid]
    return _bake_keys(m["keys"], STANCES[m["stance"]], hits=m["hit"], loop=m["loop"] if loop is None else loop,
                      lag=m["lag"], speed=speed, power=power, mirror=mirror, name=name or m["title"].replace(" ", ""),
                      root_motion=root_motion if m["travel"] else "inplace", title=m["title"], moves=[mid])


def bake_sequence(ids, **kw) -> dict:
    """Several moves in a row: each one's keys shifted after the previous (they all start and end in their stance,
    so the joins are clean; a short blend links different stances)."""
    keys, hits, t0, lags = [], [], 0.0, []
    stance = STANCES[MOVES[ids[0]]["stance"]]
    fwd = 0.0
    for n, mid in enumerate(ids):
        m = MOVES[mid]
        st = STANCES[m["stance"]]
        shift = t0 + (0.08 if n > 0 else 0.0)
        for k, key in enumerate(m["keys"]):
            if n > 0 and k == 0:
                continue  # the previous move already ends in the stance
            pose = {part: dict(spec) for part, spec in _merge(st, key["pose"]).items()}
            pose = {part: {kk: (vv if not isinstance(vv, (int, float)) else vv) for kk, vv in spec.items()} for part, spec in pose.items()}
            pose.setdefault("hips", {})["fwd"] = pose["hips"].get("fwd", 0.0) + fwd
            keys.append({"t": shift + key["t"], "pose": pose, "ease": key["ease"], "shake": key["shake"], "abs": True,
                         "empty": not key["pose"]})
        hits += [shift + h for h in m["hit"]]
        fwd += m["keys"][-1]["pose"].get("hips", {}).get("fwd", 0.0)
        t0 = shift + m["keys"][-1]["t"] - 0.12  # overlap: the next wind-up starts during the recovery
        lags.append(m["lag"])
    keys.sort(key=lambda k: k["t"])
    return _bake_keys(keys, stance, hits=hits, loop=False, lag=float(np.mean(lags)), speed=kw.get("speed", 1.0),
                      power=kw.get("power", 1.0), mirror=kw.get("mirror", False), name=kw.get("name") or "Combo",
                      root_motion=kw.get("root_motion", "inplace"), title=kw.get("title") or "Combo", moves=list(ids))


def _priority(moves, loop):
    cat = MOVES[moves[0]]["category"] if moves and moves[0] in MOVES else "combat"
    if cat == "idle":
        return "Idle"
    return "Movement" if (cat == "locomotion" and loop) else "Action"


def _blend_pose(a, b, w):
    out = {}
    for part in set(a) | set(b):
        pa, pb = a.get(part, {}), b.get(part, {})
        spec = {}
        for k in set(pa) | set(pb):
            va, vb = pa.get(k, 0), pb.get(k, 0)
            spec[k] = va + (vb - va) * w if isinstance(va, (int, float)) and isinstance(vb, (int, float)) else va
        out[part] = spec
    return out


def _resolve_holds(keys, stance, power):
    """Full pose per key. A "hold" key with no pose of its own holds the pose before it as a moving hold: it drifts
    4% toward the next key with a sine ease (a few degrees), so contact frames stay alive instead of freezing."""
    poses = [k["pose"] if k.get("abs") else _merge(stance, k["pose"], power) for k in keys]
    eases = [k["ease"] for k in keys]
    for i, k in enumerate(keys):
        if k["ease"] == "hold" and k.get("empty", not k.get("abs") and not k["pose"]) and i > 0:
            nxt = poses[i + 1] if i + 1 < len(keys) else poses[i - 1]
            poses[i] = _blend_pose(poses[i - 1], nxt, 0.04)
            eases[i] = "sine"
    return poses, eases


def _bake_keys(keys, stance, *, hits, loop, lag, speed, power, mirror, name, root_motion, title, moves):
    speed = float(np.clip(speed, 0.25, 3.0))
    poses, eases = _resolve_holds(keys, stance, power)
    # every key pose as local joint quaternions + travel
    kq, kt, kshake, times = [], [], [], []
    for key, pose in zip(keys, poses):
        if mirror:
            pose = _mirror_pose(pose)
        L, travel = _locals(pose)
        kq.append({j: _quat_from_mat(L[j]) for j in JOINTS})
        kt.append(travel)
        kshake.append(key.get("shake", 0.0))
        times.append(key["t"] / speed)
    # quaternion continuity per joint across keys (long rotations like the roll go the intended way)
    for j in JOINTS:
        for i in range(1, len(kq)):
            if np.dot(kq[i - 1][j], kq[i][j]) < 0:
                kq[i][j] = -kq[i][j]
    dur = times[-1]
    T = int(round(dur * FPS)) + 1
    seg_keys = [{"t": times[i], "ease": eases[i]} for i in range(len(keys))]
    rng = np.random.default_rng(7)
    phase = rng.uniform(0, 2 * math.pi, size=(len(JOINTS), 3))

    abs_m = {j: np.zeros((T, 3, 3)) for j in JOINTS}
    travel = np.zeros((T, 3))
    for f in range(T):
        t = f / FPS
        i, u = _sample_pose(seg_keys, None, t, power)
        travel[f] = kt[i] + (kt[i + 1] - kt[i]) * u if len(kt) > 1 else kt[0]
        shake = kshake[i] + (kshake[i + 1] - kshake[i]) * u if len(kshake) > 1 else 0.0
        local = {}
        for jn, j in enumerate(JOINTS):
            tj = t - LAG[j] * lag / max(speed, 0.5) ** 0.5
            if loop:
                tj %= max(dur, 1e-6)
            ij, uj = _sample_pose(seg_keys, None, tj, power)
            q = slerp(kq[ij][j], kq[ij + 1][j], uj) if len(kq) > 1 else kq[0][j]
            M = _mat_from_quat(q / np.linalg.norm(q))
            if shake > 0 and j in ("chest", "head", "rua", "lua", "rla", "lla"):
                amp = shake * (1.6 if j in ("rua", "lua") else 1.0)
                M = M @ _rx(amp * math.sin(t * 2 * math.pi * 11 + phase[jn, 0])) @ _rz(amp * math.sin(t * 2 * math.pi * 13 + phase[jn, 1]))
            local[j] = M
        for j in JOINTS:
            abs_m[j][f] = local[j] if j == "hips" else abs_m[PARENT[j]][f] @ local[j]

    quats = {PART[j]: quat_continuity(mats_to_quats(abs_m[j])) for j in JOINTS}
    # R6: one part per limb (a blend of the segments), torso between the pelvis and chest
    r6src = {"Torso": ("LowerTorso", "UpperTorso", 0.65), "Head": ("Head", "Head", 0.0),
             "LeftArm": ("LeftUpperArm", "LeftLowerArm", 0.3), "RightArm": ("RightUpperArm", "RightLowerArm", 0.3),
             "LeftLeg": ("LeftUpperLeg", "LeftLowerLeg", 0.25), "RightLeg": ("RightUpperLeg", "RightLowerLeg", 0.25)}
    r6q = {}
    for n, (a, b, w) in r6src.items():
        r6q[n] = quat_continuity(np.stack([slerp(quats[a][f], quats[b][f], w) for f in range(T)]))

    # root: x = right, z = back (forward travel is -Z); in-place moves keep only the small travel they author
    root = np.zeros((T, 3))
    root[:, 0] = travel[:, 1]
    root[:, 2] = -travel[:, 0]
    if root_motion == "none":
        root[:] = 0
    air = np.clip(travel[:, 2], 0, None)
    vert = np.zeros(T)
    root_full = np.concatenate([root, air[:, None], vert[:, None]], axis=1)

    hit_frames = sorted({int(round(h / speed * FPS)) for h in hits if 0 <= h / speed <= dur})
    keep = reduce_keys({n: quats[n] for n in R15_PARTS}, root_full, 0.5, 4, 0.005)
    keep = sorted(set(keep) | set(hit_frames) | {0, T - 1})

    def pack(q):
        return [[round(float(v), 5) for v in q[k]] for k in keep]

    return {
        "type": "animation", "version": 1, "name": name, "title": title, "fps": FPS,
        "duration": round(dur, 4), "loop": bool(loop), "priority": _priority(moves, loop),
        "rootMotion": root_motion, "units": "legLengths",
        "keyTimes": [round(k / FPS, 4) for k in keep],
        "parts": {n: pack(quats[n]) for n in R15_PARTS},
        "r6": {n: pack(r6q[n]) for n in r6src},
        "root": [[round(float(v), 4) for v in root[k]] for k in keep],
        "airborne": [round(float(air[k]), 4) for k in keep],
        "vertical": [0.0 for _ in keep],
        "markers": [{"name": "Hit", "t": round(f / FPS, 4)} for f in hit_frames],
        "moves": moves,
        "quality": {"source": "text", "keys": len(keep), "frames": T},
    }


# ------------------------------------------------------------------------------------------------------------ reading
SPEED_WORDS = [("very fast", 1.6), ("super fast", 1.6), ("fast", 1.3), ("quick", 1.3), ("rapid", 1.4), ("snappy", 1.2),
               ("slow motion", 0.5), ("slow-mo", 0.5), ("slowly", 0.7), ("slow", 0.7), ("lazy", 0.75)]
POWER_WORDS = [("massive", 1.3), ("huge", 1.25), ("powerful", 1.2), ("heavy", 1.2), ("strong", 1.15), ("big", 1.15),
               ("hard", 1.15), ("epic", 1.2), ("light", 0.85), ("small", 0.85), ("gentle", 0.8), ("soft", 0.85), ("tiny", 0.8)]
# "triple jump", "double slash", "jab x3", "kick three times": one move, repeated
REPEAT_WORDS = (("double", 2), ("twice", 2), ("two times", 2), ("triple", 3), ("three times", 3), ("thrice", 3),
                ("quadruple", 4), ("four times", 4), ("x2", 2), ("x3", 3), ("x4", 4), ("2x", 2), ("3x", 3), ("4x", 4))
SPLIT = re.compile(r"\s*(?:,|;|\bthen\b|\band then\b|\bfollowed by\b|\binto\b|->|=>|\bafter that\b)\s*")


def _has(text, w):
    return re.search(r"(?<![a-z])" + re.escape(w) + r"(?![a-z])", text) is not None


def catalog() -> list[dict]:
    out = [{"id": m["id"], "title": m["title"], "category": m["category"], "tags": m["tags"], "loop": m["loop"],
            "blurb": m["blurb"]} for m in MOVES.values()]
    out += [{"id": cid, "title": c[0], "category": c[1], "tags": c[2], "loop": False, "blurb": " > ".join(MOVES[i]["title"] for i in c[3])}
            for cid, c in COMBOS.items()]
    return out


def match_move(text: str) -> tuple[str | None, float]:
    """Best move (or combo) for some words: the title said outright wins, then tags."""
    from .words import normalize
    t = " " + normalize(text) + " "
    best, best_score = None, 0.0
    wants_combo = any(_has(t, w) for w in ("combo", "combination", "combos"))
    for m in catalog():
        if m["id"] in COMBOS and not wants_combo:
            continue  # "punch" is one punch; a combo needs the word
        title = m["title"].lower()
        score = 8.0 if (_has(t, title) or _has(t, title.replace(" ", ""))) else 0.0
        title_words = set(re.findall(r"[a-z0-9]+", title))
        for w in title_words:  # a title word ("kick", "roll") is a real match, however short
            if len(w) > 2 and _has(t, w):
                score += 2.5
        for w in set(re.findall(r"[a-z0-9]+", m["tags"])) - title_words:
            if len(w) > 2 and _has(t, w):  # short tag words ("two", "hit") only add a little
                score += 2 if len(w) > 4 else (1 if len(w) > 3 else 0.5)
        if m["id"] in COMBOS and _has(t, "combo"):
            score += 1.5
        if score > best_score:
            best, best_score = m["id"], score
    return best, best_score


def describe(prompt: str) -> dict:
    """What a sentence asks for: move(s), speed, power, side, loop."""
    from .words import normalize
    text = " " + normalize(prompt) + " "
    speed = next((s for w, s in SPEED_WORDS if _has(text, w)), 1.0)
    power = next((p for w, p in POWER_WORDS if _has(text, w)), 1.0)
    mirror = any(_has(text, w) for w in ("left", "left hand", "left handed", "lefty", "southpaw", "mirrored", "mirror"))
    loop = True if any(_has(text, w) for w in ("loop", "looping", "repeat", "forever", "cycle")) else None
    parts = [p for p in SPLIT.split(prompt or "") if p.strip()]
    seq = []
    if len(parts) > 1:
        for p in parts:
            mid, score = match_move(p)
            if mid and score >= 1 and mid not in COMBOS:
                seq.append(mid)
    if len(seq) < 2:
        # a plain list of moves ("jab cross hook uppercut"): the one-word move names, in the order they were said
        single = {m["title"].lower(): m["id"] for m in MOVES.values() if " " not in m["title"]}
        single.update({"backflip": "backflip", "frontflip": "frontflip", "punch": "cross", "kick": "kick"})
        listed = [single[w] for w in re.findall(r"[a-z]+", (prompt or "").lower()) if w in single]
        if len(listed) >= 2:
            seq = listed
    if len(seq) >= 2:
        return {"moves": seq, "speed": speed, "power": power, "mirror": mirror, "loop": False, "score": 9.0}
    mid, score = match_move(prompt)
    times = next((n for w, n in REPEAT_WORDS if _has(text, w)), 1)
    if mid and times > 1 and mid not in COMBOS and not MOVES[mid]["loop"]:
        return {"moves": [mid] * times, "speed": speed, "power": power, "mirror": mirror, "loop": False, "score": score}
    # "left hook" / "left jab" are the move's own lead hand, not a request to mirror
    if mid in ("jab", "hook") and not _has(text, "right"):
        mirror = False
    elif mid in ("jab", "hook") and _has(text, "right"):
        mirror = True
    return {"moves": [mid] if mid else [], "speed": speed, "power": power, "mirror": mirror, "loop": loop, "score": score}


def _as_bool(v):
    """Options from bots arrive as JSON booleans, numbers or text ("false" must not mean yes)."""
    if v is None or v == "":
        return None
    if isinstance(v, str):
        s = v.strip().lower()
        if s in ("1", "true", "yes", "on", "y"):
            return True
        if s in ("0", "false", "no", "off", "n"):
            return False
        raise ValueError(f"'{v}' is not true or false")
    return bool(v)


def _as_speed(v):
    if v is None or v == "":
        return None
    try:
        f = float(v)
    except (TypeError, ValueError):
        raise ValueError("speed must be a number (1 = normal, 2 = twice as fast)") from None
    if not math.isfinite(f) or f <= 0:
        raise ValueError("speed must be a positive number")
    return f


def from_prompt(prompt: str, name: str | None = None, speed=None, mirror=None, loop=None) -> dict:
    d = describe(prompt)
    speed, mirror, loop = _as_speed(speed), _as_bool(mirror), _as_bool(loop)
    if speed:
        d["speed"] = speed
    if mirror is not None:
        d["mirror"] = mirror
    if loop is not None:
        d["loop"] = loop
    if not d["moves"]:
        raise ValueError("No move matched. Try words like punch, kick, slash, jump, run, wave, dance, cheer, cast, beam.")
    title_words = [w.capitalize() for w in re.findall(r"[A-Za-z]+", prompt or "") if len(w) > 2][:4]
    nm = name or ("".join(title_words) or "TextAnim")[:40]
    if len(d["moves"]) > 1:
        anim = bake_sequence(d["moves"], speed=d["speed"], power=d["power"], mirror=d["mirror"], name=nm,
                             title=" > ".join(MOVES[m]["title"] for m in d["moves"]))
    else:
        anim = bake(d["moves"][0], speed=d["speed"], power=d["power"], mirror=d["mirror"], loop=d["loop"], name=nm)
    anim["prompt"] = prompt
    bits = []
    if d["speed"] != 1.0:
        bits.append("faster" if d["speed"] > 1 else "slower")
    if d["power"] != 1.0:
        bits.append("heavier" if d["power"] > 1 else "lighter")
    if d["mirror"]:
        bits.append("mirrored")
    anim["description"] = anim["title"] + (" (" + ", ".join(bits) + ")" if bits else "")
    return anim
