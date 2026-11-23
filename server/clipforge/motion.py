"""Pose landmarks -> Roblox animation data.

Input is MediaPipe BlazePose output (33 landmarks per frame, world coordinates in metres plus normalised image
coordinates). Output is a rig-independent animation: for every key, the orientation of each body part in
*character space* (Roblox axes, the character faces -Z, every part's rest orientation is the identity), the root
displacement in leg lengths and an airborne height. The Studio plugin turns that into Motor6D transforms for the
actual rig (R15 or R6, any proportions), so retargeting never assumes a particular C0/C1.

Pipeline (what makes it look hand-keyed instead of jittery mocap):
  1. fill short detection gaps, convert axes (MediaPipe: x right, y down, z away -> Roblox: x right, y up, z back)
  2. zero-phase One Euro filtering (removes jitter, keeps fast hits sharp)
  3. gravity alignment (camera pitch/roll removed) and facing normalisation (the clip starts facing forward)
  4. part frames from bone directions + twist hints (bend planes, hands, feet), with temporal continuity
  5. root motion from foot contacts (planted feet stay planted), in-place mode keeps sway but removes travel
  6. quaternion smoothing per part, optional mirror / loop blend / speed
  7. error-driven keyframe reduction (keeps every pose that matters, drops redundant keys)
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

# --- BlazePose landmark indices -------------------------------------------------------------------------------------
NOSE = 0
L_EYE, R_EYE = 2, 5
L_EAR, R_EAR = 7, 8
L_SHOULDER, R_SHOULDER = 11, 12
L_ELBOW, R_ELBOW = 13, 14
L_WRIST, R_WRIST = 15, 16
L_PINKY, R_PINKY = 17, 18
L_INDEX, R_INDEX = 19, 20
L_THUMB, R_THUMB = 21, 22
L_HIP, R_HIP = 23, 24
L_KNEE, R_KNEE = 25, 26
L_ANKLE, R_ANKLE = 27, 28
L_HEEL, R_HEEL = 29, 30
L_TOE, R_TOE = 31, 32
N_LANDMARKS = 33

R15_PARTS = [
    "LowerTorso", "UpperTorso", "Head",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
]
R6_PARTS = ["Torso", "R6Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]

# How much rotational error (degrees) each part may lose to keyframe reduction. Extremities are noisier and
# visually smaller, so they get more slack.
KEY_TOLERANCE_DEG = {
    "LowerTorso": 0.8, "UpperTorso": 0.8, "Head": 1.5,
    "LeftUpperArm": 1.0, "LeftLowerArm": 1.2, "LeftHand": 2.5,
    "RightUpperArm": 1.0, "RightLowerArm": 1.2, "RightHand": 2.5,
    "LeftUpperLeg": 1.0, "LeftLowerLeg": 1.2, "LeftFoot": 2.0,
    "RightUpperLeg": 1.0, "RightLowerLeg": 1.2, "RightFoot": 2.0,
    "Torso": 1.0, "R6Head": 1.5, "LeftArm": 1.2, "RightArm": 1.2, "LeftLeg": 1.2, "RightLeg": 1.2,
}

# Extra temporal smoothing (Gaussian sigma in frames at 30 fps) applied to each part's rotation track.
PART_SMOOTH_SIGMA = {
    "LowerTorso": 1.0, "UpperTorso": 1.0, "Head": 1.6,
    "LeftUpperArm": 0.8, "LeftLowerArm": 1.0, "LeftHand": 2.2,
    "RightUpperArm": 0.8, "RightLowerArm": 1.0, "RightHand": 2.2,
    "LeftUpperLeg": 0.8, "LeftLowerLeg": 1.0, "LeftFoot": 1.6,
    "RightUpperLeg": 0.8, "RightLowerLeg": 1.0, "RightFoot": 1.6,
    "Torso": 1.0, "R6Head": 1.6, "LeftArm": 1.0, "RightArm": 1.0, "LeftLeg": 1.0, "RightLeg": 1.0,
}

MIRROR_NAME = {
    "LeftUpperArm": "RightUpperArm", "LeftLowerArm": "RightLowerArm", "LeftHand": "RightHand",
    "LeftUpperLeg": "RightUpperLeg", "LeftLowerLeg": "RightLowerLeg", "LeftFoot": "RightFoot",
    "LeftArm": "RightArm", "LeftLeg": "RightLeg",
}
MIRROR_NAME.update({v: k for k, v in list(MIRROR_NAME.items())})


@dataclass
class AnimOptions:
    smoothing: float = 0.5          # 0 = raw, 1 = very smooth
    root_motion: str = "inplace"    # "inplace" (sway, no travel) | "full" (travels) | "none"
    lock_facing: bool = False       # remove turning (attack anims that must face forward)
    loop: bool = False              # blend the end into the start and mark the animation as looping
    mirror: bool = False            # swap left and right
    speed: float = 1.0              # playback speed multiplier baked into the key times
    key_tolerance: float = 1.0      # multiplies KEY_TOLERANCE_DEG (higher = fewer keys)
    max_key_gap: int = 6            # frames; never leave a longer gap without a key
    gravity_align: bool = True
    name: str = "ClipForgeAnim"
    priority: str = "Action"
    fps: float = 30.0
    extra: dict = field(default_factory=dict)

    @staticmethod
    def from_dict(d: dict | None) -> "AnimOptions":
        o = AnimOptions()
        if not d:
            return o
        mapping = {
            "smoothing": ("smoothing", float), "rootMotion": ("root_motion", str), "root_motion": ("root_motion", str),
            "lockFacing": ("lock_facing", bool), "lock_facing": ("lock_facing", bool), "loop": ("loop", bool),
            "mirror": ("mirror", bool), "speed": ("speed", float), "keyTolerance": ("key_tolerance", float),
            "key_tolerance": ("key_tolerance", float), "name": ("name", str), "priority": ("priority", str),
            "gravityAlign": ("gravity_align", bool),
        }
        for k, v in d.items():
            if k in mapping and v is not None:
                attr, typ = mapping[k]
                setattr(o, attr, typ(v))
        o.smoothing = float(np.clip(o.smoothing, 0.0, 1.0))
        o.speed = float(np.clip(o.speed, 0.1, 4.0))
        if o.root_motion not in ("inplace", "full", "none"):
            o.root_motion = "inplace"
        return o


# --- small vector helpers -------------------------------------------------------------------------------------------
def _norm(v, eps=1e-9):
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, eps), n[..., 0]


def _ortho(v, axis):
    """Component of v perpendicular to the unit vector axis (row-wise)."""
    return v - np.sum(v * axis, axis=-1, keepdims=True) * axis


def frame_right_up(right, up_hint):
    """Rotation matrices (T,3,3) whose columns are [right, up, back]; right is exact."""
    r, _ = _norm(right)
    u, _ = _norm(_ortho(up_hint, r))
    b = np.cross(r, u)
    return np.stack([r, u, b], axis=-1)


def frame_up_back(up, back_hint):
    """Columns [right, up, back]; up is exact."""
    u, _ = _norm(up)
    b, _ = _norm(_ortho(back_hint, u))
    r = np.cross(u, b)
    return np.stack([r, u, b], axis=-1)


def frame_right_back(right, back_hint):
    r, _ = _norm(right)
    b, _ = _norm(_ortho(back_hint, r))
    u = np.cross(b, r)
    return np.stack([r, u, b], axis=-1)


def frame_back_up(back, up_hint):
    b, _ = _norm(back)
    u, _ = _norm(_ortho(up_hint, b))
    r = np.cross(u, b)
    return np.stack([r, u, b], axis=-1)


def rot_y(angle):
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]])


def rot_between(a, b):
    """Rotation matrix taking unit vector a onto unit vector b."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c > 1 - 1e-9:
        return np.eye(3)
    if c < -1 + 1e-9:
        axis = np.cross(a, [1.0, 0.0, 0.0])
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(a, [0.0, 0.0, 1.0])
        axis /= np.linalg.norm(axis)
        return 2 * np.outer(axis, axis) - np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1 / (1 + c))


def mats_to_quats(m):
    """(T,3,3) rotation matrices -> (T,4) quaternions [x, y, z, w]."""
    m = np.asarray(m, dtype=np.float64)
    t = m.shape[0]
    q = np.empty((t, 4))
    tr = m[:, 0, 0] + m[:, 1, 1] + m[:, 2, 2]
    for i in range(t):
        a = m[i]
        if tr[i] > 0:
            s = math.sqrt(tr[i] + 1.0) * 2
            q[i] = [(a[2, 1] - a[1, 2]) / s, (a[0, 2] - a[2, 0]) / s, (a[1, 0] - a[0, 1]) / s, 0.25 * s]
        elif a[0, 0] > a[1, 1] and a[0, 0] > a[2, 2]:
            s = math.sqrt(1.0 + a[0, 0] - a[1, 1] - a[2, 2]) * 2
            q[i] = [0.25 * s, (a[0, 1] + a[1, 0]) / s, (a[0, 2] + a[2, 0]) / s, (a[2, 1] - a[1, 2]) / s]
        elif a[1, 1] > a[2, 2]:
            s = math.sqrt(1.0 + a[1, 1] - a[0, 0] - a[2, 2]) * 2
            q[i] = [(a[0, 1] + a[1, 0]) / s, 0.25 * s, (a[1, 2] + a[2, 1]) / s, (a[0, 2] - a[2, 0]) / s]
        else:
            s = math.sqrt(1.0 + a[2, 2] - a[0, 0] - a[1, 1]) * 2
            q[i] = [(a[0, 2] + a[2, 0]) / s, (a[1, 2] + a[2, 1]) / s, 0.25 * s, (a[1, 0] - a[0, 1]) / s]
    q /= np.linalg.norm(q, axis=1, keepdims=True)
    return q


def quats_to_mats(q):
    x, y, z, w = q[:, 0], q[:, 1], q[:, 2], q[:, 3]
    m = np.empty((q.shape[0], 3, 3))
    m[:, 0, 0] = 1 - 2 * (y * y + z * z)
    m[:, 0, 1] = 2 * (x * y - z * w)
    m[:, 0, 2] = 2 * (x * z + y * w)
    m[:, 1, 0] = 2 * (x * y + z * w)
    m[:, 1, 1] = 1 - 2 * (x * x + z * z)
    m[:, 1, 2] = 2 * (y * z - x * w)
    m[:, 2, 0] = 2 * (x * z - y * w)
    m[:, 2, 1] = 2 * (y * z + x * w)
    m[:, 2, 2] = 1 - 2 * (x * x + y * y)
    return m


def quat_continuity(q):
    q = q.copy()
    for i in range(1, len(q)):
        if np.dot(q[i], q[i - 1]) < 0:
            q[i] = -q[i]
    return q


def slerp(q0, q1, u):
    d = float(np.dot(q0, q1))
    if d < 0:
        q1, d = -q1, -d
    if d > 0.9995:
        r = q0 + u * (q1 - q0)
        return r / np.linalg.norm(r)
    th = math.acos(min(1.0, d))
    s = math.sin(th)
    return (math.sin((1 - u) * th) * q0 + math.sin(u * th) * q1) / s


def quat_angle_deg(q0, q1):
    d = abs(float(np.dot(q0, q1)))
    return math.degrees(2 * math.acos(min(1.0, d)))


def gaussian_kernel(sigma):
    if sigma <= 0.05:
        return np.array([1.0])
    radius = max(1, int(math.ceil(sigma * 3)))
    x = np.arange(-radius, radius + 1)
    k = np.exp(-(x * x) / (2 * sigma * sigma))
    return k / k.sum()


def smooth_series(x, sigma):
    """Gaussian smoothing along axis 0 with edge padding (x: (T, ...))."""
    k = gaussian_kernel(sigma)
    if len(k) == 1 or x.shape[0] < 3:
        return x.copy()
    r = len(k) // 2
    pad = np.concatenate([np.repeat(x[:1], r, axis=0), x, np.repeat(x[-1:], r, axis=0)], axis=0)
    out = np.zeros_like(x, dtype=np.float64)
    for i, w in enumerate(k):
        out += w * pad[i:i + x.shape[0]]
    return out


# --- filtering ------------------------------------------------------------------------------------------------------
def one_euro(x, fps, min_cutoff, beta, d_cutoff=1.0):
    """Causal One Euro filter over axis 0 of x (T, D)."""
    x = np.asarray(x, dtype=np.float64)
    out = np.empty_like(x)
    dt = 1.0 / fps

    def alpha(cutoff):
        tau = 1.0 / (2 * np.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)

    prev = x[0].copy()
    dprev = np.zeros_like(prev)
    out[0] = prev
    a_d = alpha(d_cutoff)
    for t in range(1, x.shape[0]):
        dx = (x[t] - prev) / dt
        dhat = a_d * dx + (1 - a_d) * dprev
        a = alpha(min_cutoff + beta * np.abs(dhat))
        prev = a * x[t] + (1 - a) * prev
        dprev = dhat
        out[t] = prev
    return out


def zero_phase_one_euro(x, fps, min_cutoff, beta):
    fwd = one_euro(x, fps, min_cutoff, beta)
    bwd = one_euro(x[::-1], fps, min_cutoff, beta)[::-1]
    return 0.5 * (fwd + bwd)


def fill_gaps(arr, valid):
    """Linear interpolation over time for frames where valid is False. arr: (T, ...)."""
    arr = arr.copy()
    idx = np.flatnonzero(valid)
    if len(idx) == 0:
        return arr
    t = np.arange(arr.shape[0])
    flat = arr.reshape(arr.shape[0], -1)
    for c in range(flat.shape[1]):
        flat[:, c] = np.interp(t, idx, flat[idx, c])
    return flat.reshape(arr.shape)


# --- the pipeline ---------------------------------------------------------------------------------------------------
def to_roblox_axes(world):
    """MediaPipe world (x right, y down, z away from camera) -> Roblox-style (x right, y up, z towards camera)."""
    out = world.copy()
    out[..., 1] *= -1
    out[..., 2] *= -1
    return out


def _mid(p, a, b):
    return 0.5 * (p[:, a] + p[:, b])


def align_world(P, gravity_align=True):
    """Rotate the whole clip so 'up' is +Y and the first frames face -Z (Roblox forward). Returns (P, R)."""
    T = P.shape[0]
    R = np.eye(3)
    if gravity_align:
        hip = _mid(P, L_HIP, R_HIP)
        sh = _mid(P, L_SHOULDER, R_SHOULDER)
        ank = _mid(P, L_ANKLE, R_ANKLE)
        # frames with straight legs: the hip->ankle line is vertical when standing
        def knee_angle(h, k, a):
            v1, _ = _norm(P[:, h] - P[:, k])
            v2, _ = _norm(P[:, a] - P[:, k])
            return np.degrees(np.arccos(np.clip(np.sum(v1 * v2, axis=1), -1, 1)))
        straight = (knee_angle(L_HIP, L_KNEE, L_ANKLE) > 165) & (knee_angle(R_HIP, R_KNEE, R_ANKLE) > 165)
        legs_up, _ = _norm(hip - ank)
        spine_up, _ = _norm(sh - hip)
        if straight.sum() >= max(5, 0.15 * T):
            up = np.median(legs_up[straight], axis=0)
        else:
            up = np.median(spine_up, axis=0)
        up /= np.linalg.norm(up)
        # only trust it for moderate camera tilt (otherwise the subject may simply be lying down)
        if np.degrees(np.arccos(np.clip(up[1], -1, 1))) < 40:
            R = rot_between(up, np.array([0.0, 1.0, 0.0]))
    P = P @ R.T
    # facing: look = up x right; rotate around Y so the first second faces -Z
    n0 = max(1, min(T, 15))
    right = P[:n0, R_HIP] - P[:n0, L_HIP] + 0.5 * (P[:n0, R_SHOULDER] - P[:n0, L_SHOULDER])
    right = right.mean(axis=0)
    right[1] = 0
    if np.linalg.norm(right) > 1e-6:
        right /= np.linalg.norm(right)
        look = np.cross([0.0, 1.0, 0.0], right)
        yaw = math.atan2(look[0], look[2])  # angle of look around Y, measured from +Z
        target = math.atan2(0.0, -1.0)      # -Z
        Ry = rot_y(target - yaw)
        P = P @ Ry.T
        R = Ry @ R
    return P, R


def part_frames(P):
    """Orientation matrices per part, (T,3,3) each, in the aligned world frame."""
    T = P.shape[0]
    hip = _mid(P, L_HIP, R_HIP)
    sh = _mid(P, L_SHOULDER, R_SHOULDER)
    spine = sh - hip
    knees = _mid(P, L_KNEE, R_KNEE)
    thigh_dir, _ = _norm(knees - hip)
    spine_dir, _ = _norm(spine)
    frames = {}

    frames["LowerTorso"] = frame_right_up(P[:, R_HIP] - P[:, L_HIP], 0.55 * spine_dir - 0.45 * thigh_dir)
    frames["UpperTorso"] = frame_right_up(P[:, R_SHOULDER] - P[:, L_SHOULDER], spine)
    ear_mid = _mid(P, L_EAR, R_EAR)
    eye_mid = _mid(P, L_EYE, R_EYE)
    head_fwd = 0.7 * (eye_mid - ear_mid) + 0.3 * (P[:, NOSE] - ear_mid)
    frames["Head"] = frame_right_back(P[:, R_EAR] - P[:, L_EAR], -head_fwd)

    ut_back = frames["UpperTorso"][:, :, 2]
    lt_back = frames["LowerTorso"][:, :, 2]

    def limb(up, back_hint, prev_weight, fallback):
        """Frame with exact up axis; twist from back_hint, regularised by the previous frame for stability."""
        out = np.empty((T, 3, 3))
        u_all, _ = _norm(up)
        prev = None
        for t in range(T):
            u = u_all[t]
            b = back_hint[t] - np.dot(back_hint[t], u) * u
            strength = np.linalg.norm(b)
            if prev is not None:
                pb = prev - np.dot(prev, u) * u
                b = b + prev_weight * pb * max(0.0, 1.0 - strength * 3)  # lean on history when the hint is weak
                if strength < 0.12:
                    b = b + pb * (0.12 - strength) * 8
            if np.linalg.norm(b) < 1e-6:
                fb = fallback[t] - np.dot(fallback[t], u) * u
                b = fb if np.linalg.norm(fb) > 1e-6 else np.cross(u, [1.0, 0.0, 0.0])
            b /= np.linalg.norm(b)
            r = np.cross(u, b)
            out[t] = np.stack([r, u, b], axis=-1)
            prev = b
        return out

    for side, (S, E, W, PK, IX, H, K, A, HE, TO) in {
        "Left": (L_SHOULDER, L_ELBOW, L_WRIST, L_PINKY, L_INDEX, L_HIP, L_KNEE, L_ANKLE, L_HEEL, L_TOE),
        "Right": (R_SHOULDER, R_ELBOW, R_WRIST, R_PINKY, R_INDEX, R_HIP, R_KNEE, R_ANKLE, R_HEEL, R_TOE),
    }.items():
        upper = P[:, S] - P[:, E]                       # elbow -> shoulder
        fore_dir, _ = _norm(P[:, W] - P[:, E])          # elbow -> wrist
        ua, _ = _norm(upper)
        bend = _ortho(fore_dir, ua)                      # forearm swings towards the front (-Z) in rest
        knuckles, _ = _norm(P[:, IX] - P[:, PK])         # pinky -> index points forward (-Z) in rest
        frames[side + "UpperArm"] = limb(upper, -bend, 0.6, ut_back)
        lower_up = P[:, E] - P[:, W]
        frames[side + "LowerArm"] = limb(lower_up, -knuckles, 0.8, frames[side + "UpperArm"][:, :, 2])
        hand_tip = 0.5 * (P[:, IX] + P[:, PK])
        frames[side + "Hand"] = limb(P[:, W] - hand_tip, -knuckles, 0.8, frames[side + "LowerArm"][:, :, 2])

        thigh = P[:, H] - P[:, K]                       # knee -> hip
        th, _ = _norm(thigh)
        shin_dir, _ = _norm(P[:, A] - P[:, K])           # knee -> ankle
        foot_fwd, _ = _norm(P[:, TO] - P[:, HE])         # heel -> toe
        knee_bend = _ortho(shin_dir, th)                 # shin swings back (+Z) when the knee bends
        frames[side + "UpperLeg"] = limb(thigh, knee_bend - 0.35 * foot_fwd, 0.6, lt_back)
        frames[side + "LowerLeg"] = limb(P[:, K] - P[:, A], -foot_fwd, 0.6, frames[side + "UpperLeg"][:, :, 2])
        frames[side + "Foot"] = frame_back_up(-foot_fwd, frames[side + "LowerLeg"][:, :, 1])

    # R6: one part per limb, whole-limb directions
    frames["Torso"] = frame_right_up((P[:, R_SHOULDER] - P[:, L_SHOULDER]) + (P[:, R_HIP] - P[:, L_HIP]), spine)
    frames["R6Head"] = frames["Head"]
    for side, (S, E, W, H, K, A, HE, TO) in {
        "Left": (L_SHOULDER, L_ELBOW, L_WRIST, L_HIP, L_KNEE, L_ANKLE, L_HEEL, L_TOE),
        "Right": (R_SHOULDER, R_ELBOW, R_WRIST, R_HIP, R_KNEE, R_ANKLE, R_HEEL, R_TOE),
    }.items():
        arm = P[:, S] - P[:, W]
        a_dir, _ = _norm(arm)
        elbow_off = _ortho(P[:, E] - P[:, S], a_dir)    # elbow sticks out backwards when the arm bends
        frames[side + "Arm"] = limb(arm, elbow_off, 0.6, frames["Torso"][:, :, 2])
        leg = P[:, H] - P[:, A]
        foot_fwd, _ = _norm(P[:, TO] - P[:, HE])
        frames[side + "Leg"] = limb(leg, -foot_fwd, 0.6, frames["Torso"][:, :, 2])
    return frames


def calibrate_feet(frames, P):
    """Remove the constant pitch offset of the heel->toe landmarks (they don't lie flat on the ground)."""
    for side, (HE, TO, K, A) in {"Left": (L_HEEL, L_TOE, L_KNEE, L_ANKLE),
                                 "Right": (R_HEEL, R_TOE, R_KNEE, R_ANKLE)}.items():
        fwd, _ = _norm(P[:, TO] - P[:, HE])
        shin, _ = _norm(P[:, K] - P[:, A])
        low = P[:, [HE, TO], 1].min(axis=1)
        ground = np.minimum(P[:, [L_HEEL, L_TOE], 1].min(axis=1), P[:, [R_HEEL, R_TOE], 1].min(axis=1))
        # a planted foot under a near-vertical shin is standing flat: its heel->toe pitch is the landmark bias
        planted = (low < ground + 0.03) & (shin[:, 1] > math.cos(math.radians(20)))
        if planted.sum() < 5:
            continue
        pitch = np.degrees(np.arcsin(np.clip(fwd[planted, 1], -1, 1)))
        offset = float(np.median(pitch))
        if abs(offset) < 1 or abs(offset) > 25:
            continue
        # rotate each foot frame about its own right axis so the planted median lies flat
        ang = math.radians(-offset)
        c, s = math.cos(ang), math.sin(ang)
        Rx = np.array([[1, 0, 0], [0, c, -s], [0, s, c]])  # local rotation about +X (pitch)
        frames[side + "Foot"] = frames[side + "Foot"] @ Rx
    return frames


def calibrate_head(frames):
    """Ear/eye landmarks don't define 'looking straight ahead' exactly: treat the clip's median head pitch
    relative to the chest as neutral (people mostly look forward)."""
    ut = frames["UpperTorso"]
    hd = frames["Head"]
    rel = np.einsum("tji,tjk->tik", ut, hd)            # UT^T @ Head
    fwd = -rel[:, :, 2]                                 # head forward (-Z) in chest space
    pitch = np.degrees(np.arctan2(fwd[:, 1], -fwd[:, 2]))
    offset = float(np.median(pitch))
    if 1.0 < abs(offset) < 30.0:
        ang = math.radians(-offset)                     # rotate about local +X to cancel the median pitch
        c, s = math.cos(ang), math.sin(ang)
        Rx = np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
        frames["Head"] = hd @ Rx
        frames["R6Head"] = frames["Head"]
    return frames


def root_motion(P, img, vis, fps, mode):
    """Root displacement (T,3) and airborne height (T,) in metres, plus the standing hip height in metres."""
    T = P.shape[0]
    feetL = P[:, [L_HEEL, L_TOE, L_ANKLE]]
    feetR = P[:, [R_HEEL, R_TOE, R_ANKLE]]
    lowL = feetL[:, :2, 1].min(axis=1)
    lowR = feetR[:, :2, 1].min(axis=1)
    g = np.minimum(lowL, lowR)
    hip_height = -g                                     # hips are the origin
    standing = float(np.percentile(hip_height, 90)) if T > 0 else 0.9
    standing = max(standing, 0.3)

    # airborne height from the 2D track: lowest foot above its running ground line
    airborne = np.zeros(T)
    if img is not None and T > 10:
        foot_y = np.maximum(img[:, [L_HEEL, L_TOE], 1].max(axis=1), img[:, [R_HEEL, R_TOE], 1].max(axis=1))
        hip2d = 0.5 * (img[:, L_HIP, :2] + img[:, R_HIP, :2])
        ank2d = 0.5 * (img[:, L_ANKLE, :2] + img[:, R_ANKLE, :2])
        leg_px = np.linalg.norm(hip2d - ank2d, axis=1)
        leg_m = np.linalg.norm(0.5 * (P[:, L_HIP] + P[:, R_HIP]) - 0.5 * (P[:, L_ANKLE] + P[:, R_ANKLE]), axis=1)
        ppm = smooth_series(np.maximum(leg_px, 1e-4) / np.maximum(leg_m, 0.2), 6)
        win = int(fps * 1.5)
        ground = np.array([np.percentile(foot_y[max(0, i - win):i + win + 1], 85) for i in range(T)])
        ground = smooth_series(ground, fps * 0.3)
        elev = (ground - foot_y) / ppm
        both_up = np.minimum(ground - img[:, [L_HEEL, L_TOE], 1].max(axis=1),
                             ground - img[:, [R_HEEL, R_TOE], 1].max(axis=1)) / ppm
        air = (both_up > 0.06) & (elev > 0.06)
        # only trust short, clean airborne runs (jumps), not slow camera drift
        airborne = np.where(air, np.clip(elev, 0, 1.2), 0.0)
        airborne = smooth_series(airborne, 1.2)

    root = np.zeros((T, 3))
    if mode != "none":
        eps = 0.035
        cL = lowL < g + eps
        cR = lowR < g + eps
        vel = np.zeros(3)
        ancL = feetL.mean(axis=1)
        ancR = feetR.mean(axis=1)
        for t in range(1, T):
            deltas = []
            if airborne[t] < 0.05:
                if cL[t] and cL[t - 1]:
                    deltas.append(-(ancL[t] - ancL[t - 1]))
                if cR[t] and cR[t - 1]:
                    deltas.append(-(ancR[t] - ancR[t - 1]))
            if deltas:
                d = np.mean(deltas, axis=0)
                d[1] = 0.0
                # reject single-frame teleports from detection glitches
                if np.linalg.norm(d) > 0.25:
                    d *= 0.25 / np.linalg.norm(d)
                vel = d
            else:
                vel = vel * 0.9
                d = vel
            root[t] = root[t - 1] + d
        root = smooth_series(root, 1.5)
        if mode == "inplace":
            drift = smooth_series(root, fps * 0.7)
            sway = root - drift
            mag = np.linalg.norm(sway, axis=1, keepdims=True)
            limit = 0.35 * standing
            root = sway * (limit * np.tanh(mag / limit) / np.maximum(mag, 1e-9))
        root -= root[0]
    vertical = hip_height - standing                     # negative when crouching
    return root, airborne, vertical, standing


def reduce_keys(tracks, root, tol_scale, max_gap, root_tol):
    """Greedy split: keep the frame with the worst interpolation error until every part is within tolerance."""
    T = root.shape[0]
    if T <= 2:
        return list(range(T))
    names = list(tracks.keys())
    keep = {0, T - 1}

    def worst(i, j):
        best_k, best_err = -1, 0.0
        for k in range(i + 1, j):
            u = (k - i) / (j - i)
            err = 0.0
            for n in names:
                q = tracks[n]
                a = quat_angle_deg(q[k], slerp(q[i], q[j], u)) / (KEY_TOLERANCE_DEG.get(n, 1.0) * tol_scale)
                if a > err:
                    err = a
            rp = root[i] + u * (root[j] - root[i])
            e = float(np.linalg.norm(root[k] - rp)) / root_tol
            err = max(err, e)
            if err > best_err:
                best_k, best_err = k, err
        return best_k, best_err

    stack = [(0, T - 1)]
    while stack:
        i, j = stack.pop()
        if j - i <= 1:
            continue
        k, err = worst(i, j)
        if err > 1.0 or (j - i) > max_gap:
            if err <= 1.0:
                k = (i + j) // 2
            keep.add(k)
            stack.append((i, k))
            stack.append((k, j))
    return sorted(keep)


HIT_POINTS = (15, 16, 27, 28)  # MediaPipe wrists and ankles


def detect_hits(P: np.ndarray, fps: float, max_hits: int = 8) -> list[int]:
    """Contact frames in a clip: a hand or foot moving fast relative to the hips, then stopping sharply. That is the
    frame a punch, kick or slash lands, where effects, hit-stop and damage belong. P = (T, 33, 3) in metres."""
    T = P.shape[0]
    if T < 6:
        return []
    hip = (P[:, 23] + P[:, 24]) / 2
    rel = P[:, list(HIT_POINTS)] - hip[:, None, :]
    speed = (np.linalg.norm(np.diff(rel, axis=0), axis=2) * fps).max(axis=1)  # m/s between frames i and i+1
    speed = np.convolve(np.pad(speed, 1, mode="edge"), [0.25, 0.5, 0.25], mode="valid")
    top = float(speed.max())
    if top < 2.0:  # nothing faster than a brisk gesture
        return []
    thr = max(2.0, 0.45 * top)
    window = max(2, int(round(0.15 * fps)))
    gap = max(1, int(round(0.18 * fps)))
    hits: list[tuple[int, float]] = []
    for i in range(1, len(speed) - 1):
        if not (speed[i] >= thr and speed[i] >= speed[i - 1] and speed[i] > speed[i + 1]):
            continue
        after = speed[i + 1:i + 1 + window]
        if not len(after) or after.min() >= 0.5 * speed[i]:
            continue  # it keeps moving: a swing through, not a contact
        stop = next(i + 1 + n for n, v in enumerate(after) if v < 0.6 * speed[i])
        frame = min(stop + 1, T - 1)
        if hits and frame - hits[-1][0] < gap:
            if speed[i] > hits[-1][1]:
                hits[-1] = (frame, float(speed[i]))
            continue
        hits.append((frame, float(speed[i])))
    if len(hits) > max_hits:
        hits = sorted(sorted(hits, key=lambda h: -h[1])[:max_hits])
    return [f for f, _ in hits]


def build_animation(pose: dict, opts: AnimOptions) -> dict:
    """pose = {"world": (T,33,3), "image": (T,33,3), "visibility": (T,33), "detected": (T,), "fps": float}."""
    fps = float(pose.get("fps") or 30.0)
    world = np.asarray(pose["world"], dtype=np.float64)
    image = np.asarray(pose["image"], dtype=np.float64) if pose.get("image") is not None else None
    vis = np.asarray(pose["visibility"], dtype=np.float64) if pose.get("visibility") is not None else None
    detected = np.asarray(pose.get("detected", np.ones(world.shape[0], dtype=bool)), dtype=bool)
    T = world.shape[0]
    if T < 2 or detected.sum() < 2:
        raise ValueError("No person was detected in the video (need a clearly visible full body).")

    world = fill_gaps(world, detected)
    if image is not None:
        image = fill_gaps(image, detected)

    P = to_roblox_axes(world)
    s = opts.smoothing
    if s > 0:
        min_cut = 3.2 - 2.6 * s           # Hz at rest
        beta = 0.9 - 0.65 * s
        P = zero_phase_one_euro(P.reshape(T, -1), fps, min_cut, beta).reshape(T, N_LANDMARKS, 3)
        if image is not None:
            image = zero_phase_one_euro(image.reshape(T, -1), fps, min_cut, beta * 4).reshape(image.shape)

    P, _ = align_world(P, opts.gravity_align)
    hit_frames = detect_hits(P, fps)
    frames = part_frames(P)
    frames = calibrate_feet(frames, P)
    frames = calibrate_head(frames)

    root, airborne, vertical, standing = root_motion(P, image, vis, fps, opts.root_motion)

    if opts.lock_facing:
        # remove the yaw of the pelvis from everything (keeps the character facing forward)
        right = frames["LowerTorso"][:, :, 0].copy()
        right[:, 1] = 0
        right, _ = _norm(right)
        yaw = np.arctan2(-right[:, 2], right[:, 0])
        for n in frames:
            frames[n] = np.einsum("tij,tjk->tik", np.stack([rot_y(-a) for a in yaw]), frames[n])
        root = np.einsum("tij,tj->ti", np.stack([rot_y(-a) for a in yaw]), root)

    quats = {}
    smooth_scale = 1.5 * s
    for n, m in frames.items():
        q = quat_continuity(mats_to_quats(m))
        sig = PART_SMOOTH_SIGMA.get(n, 1.0) * smooth_scale * (fps / 30.0)
        q = smooth_series(q, sig)
        q /= np.linalg.norm(q, axis=1, keepdims=True)
        quats[n] = quat_continuity(q)

    # units: leg lengths (standing hip height above the ground)
    root_ll = root / standing
    air_ll = airborne / standing
    vert_ll = vertical / standing

    if opts.mirror:
        mq = {}
        for n, q in quats.items():
            m = q.copy()
            m[:, 1] *= -1
            m[:, 2] *= -1
            mq[MIRROR_NAME.get(n, n)] = m
        quats = mq
        root_ll = root_ll.copy()
        root_ll[:, 0] *= -1

    loop = opts.loop
    if loop and T > 20:
        blend = min(int(fps * 0.3), T // 4)
        for n, q in quats.items():
            for k in range(blend):
                u = (k + 1) / (blend + 1)
                w = u * u * (3 - 2 * u)
                q[T - blend + k] = slerp(q[T - blend + k], q[0], w)
            quats[n] = quat_continuity(q)
        for arr in (root_ll, air_ll, vert_ll):
            for k in range(blend):
                u = (k + 1) / (blend + 1)
                w = u * u * (3 - 2 * u)
                arr[T - blend + k] = arr[T - blend + k] * (1 - w) + arr[0] * w

    root_full = np.concatenate([root_ll, air_ll[:, None], vert_ll[:, None]], axis=1)
    r15_tracks = {n: quats[n] for n in R15_PARTS}
    keys = reduce_keys(r15_tracks, root_full, opts.key_tolerance, opts.max_key_gap, root_tol=0.01)
    keys = sorted(set(keys) | {f for f in hit_frames if 0 <= f < T})  # a key on every contact frame
    r6_keys = keys  # same time slices keep both rigs in sync

    dur_frames = T - 1
    times = [round(k / fps / opts.speed, 4) for k in keys]

    def pack(q):
        return [[round(float(v), 5) for v in q[k]] for k in keys]

    out_parts = {n: pack(quats[n]) for n in R15_PARTS}
    out_r6 = {
        "Torso": pack(quats["Torso"]), "Head": pack(quats["R6Head"]),
        "LeftArm": pack(quats["LeftArm"]), "RightArm": pack(quats["RightArm"]),
        "LeftLeg": pack(quats["LeftLeg"]), "RightLeg": pack(quats["RightLeg"]),
    }
    quality = {
        "detectedRatio": round(float(detected.mean()), 3),
        "keys": len(keys),
        "frames": int(T),
        "standingHipHeightM": round(standing, 3),
    }
    if vis is not None:
        quality["meanVisibility"] = round(float(np.nanmean(vis)), 3)
    return {
        "type": "animation",
        "version": 1,
        "name": opts.name,
        "fps": fps,
        "duration": round(dur_frames / fps / opts.speed, 4),
        "loop": bool(loop),
        "priority": opts.priority,
        "rootMotion": opts.root_motion,
        "units": "legLengths",
        "keyTimes": times,
        "parts": out_parts,
        "r6": out_r6,
        "root": [[round(float(v), 4) for v in root_ll[k]] for k in keys],
        "airborne": [round(float(air_ll[k]), 4) for k in keys],
        "vertical": [round(float(vert_ll[k]), 4) for k in keys],
        "markers": [{"name": "Hit", "t": round(f / fps / opts.speed, 4)} for f in hit_frames],
        "quality": quality,
    }
