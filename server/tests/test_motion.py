"""Round-trip tests for the retargeting math: synthesise BlazePose landmarks from known part orientations, run
them through the pipeline and check the orientations come back. Run:  python tests/test_motion.py"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from clipforge import motion as M  # noqa: E402


def Rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def Ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def Rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def d(x):
    return math.radians(x)


def random_pose(rng, rest=False):
    """Relative joint rotations (character space: faces -Z, +X = the character's right)."""
    if rest:
        return {k: np.eye(3) for k in ["LT", "UT", "H", "LUA", "LLA", "LH", "RUA", "RLA", "RH",
                                       "LUL", "LLL", "LF", "RUL", "RLL", "RF"]}
    u = lambda a, b: d(rng.uniform(a, b))  # noqa: E731
    p = {
        "LT": Ry(u(-60, 60)) @ Rx(u(-12, 12)) @ Rz(u(-8, 8)),
        "UT": Ry(u(-30, 30)) @ Rx(u(-20, 30)) @ Rz(u(-15, 15)),
        "H": Ry(u(-40, 40)) @ Rx(u(-20, 20)) @ Rz(u(-10, 10)),
    }
    for s in "LR":
        p[s + "UA"] = Rz(u(-70, 70)) @ Rx(u(-80, 80)) @ Ry(u(-40, 40))
        p[s + "LA"] = Rx(u(30, 120)) @ Ry(u(-40, 40))             # elbow flexion + pronation
        p[s + "H"] = Rx(u(-25, 25)) @ Rz(u(-20, 20))              # wrist bend, no twist
        p[s + "UL"] = Rx(u(-20, 60)) @ Rz(u(-25, 25)) @ Ry(u(-25, 25))
        p[s + "LL"] = Rx(u(-100, -20))                            # knee flexion only
        p[s + "F"] = Rx(u(-20, 25))                               # ankle flexion only
    return p


def world_orients(p):
    w = {"LowerTorso": p["LT"]}
    w["UpperTorso"] = w["LowerTorso"] @ p["UT"]
    w["Head"] = w["UpperTorso"] @ p["H"]
    for s, side in (("L", "Left"), ("R", "Right")):
        w[side + "UpperArm"] = w["UpperTorso"] @ p[s + "UA"]
        w[side + "LowerArm"] = w[side + "UpperArm"] @ p[s + "LA"]
        w[side + "Hand"] = w[side + "LowerArm"] @ p[s + "H"]
        w[side + "UpperLeg"] = w["LowerTorso"] @ p[s + "UL"]
        w[side + "LowerLeg"] = w[side + "UpperLeg"] @ p[s + "LL"]
        w[side + "Foot"] = w[side + "LowerLeg"] @ p[s + "F"]
    return w


def landmarks(w):
    """33 BlazePose landmarks (character space, metres, hips at the origin)."""
    L = np.zeros((33, 3))
    v = lambda R, x, y, z: R @ np.array([x, y, z])  # noqa: E731
    LT, UT, H = w["LowerTorso"], w["UpperTorso"], w["Head"]
    L[M.L_HIP] = v(LT, -0.1, 0, 0)
    L[M.R_HIP] = v(LT, 0.1, 0, 0)
    sh = v(UT, 0, 0.5, 0)
    L[M.L_SHOULDER] = sh + v(UT, -0.18, 0, 0)
    L[M.R_SHOULDER] = sh + v(UT, 0.18, 0, 0)
    hc = sh + v(UT, 0, 0.08, 0) + v(H, 0, 0.1, 0)
    L[M.L_EAR] = hc + v(H, -0.075, 0, 0)
    L[M.R_EAR] = hc + v(H, 0.075, 0, 0)
    L[M.L_EYE] = hc + v(H, -0.032, 0.0, -0.085)
    L[M.R_EYE] = hc + v(H, 0.032, 0.0, -0.085)
    L[M.NOSE] = hc + v(H, 0, -0.03, -0.1)
    for s, sign in (("Left", -1), ("Right", 1)):
        S, E, W_, PK, IX, TH = ((M.L_SHOULDER, M.L_ELBOW, M.L_WRIST, M.L_PINKY, M.L_INDEX, M.L_THUMB) if s == "Left"
                                else (M.R_SHOULDER, M.R_ELBOW, M.R_WRIST, M.R_PINKY, M.R_INDEX, M.R_THUMB))
        L[E] = L[S] + v(w[s + "UpperArm"], 0, -0.28, 0)
        L[W_] = L[E] + v(w[s + "LowerArm"], 0, -0.25, 0)
        L[IX] = L[W_] + v(w[s + "Hand"], 0, -0.085, -0.03)
        L[PK] = L[W_] + v(w[s + "Hand"], 0, -0.075, 0.03)
        L[TH] = L[W_] + v(w[s + "Hand"], -sign * 0.02, -0.04, -0.045)
        Hh, K, A, HE, TO = ((M.L_HIP, M.L_KNEE, M.L_ANKLE, M.L_HEEL, M.L_TOE) if s == "Left"
                            else (M.R_HIP, M.R_KNEE, M.R_ANKLE, M.R_HEEL, M.R_TOE))
        L[K] = L[Hh] + v(w[s + "UpperLeg"], 0, -0.42, 0)
        L[A] = L[K] + v(w[s + "LowerLeg"], 0, -0.40, 0)
        L[HE] = L[A] + v(w[s + "Foot"], 0, -0.05, 0.06)
        L[TO] = L[A] + v(w[s + "Foot"], 0, -0.07, -0.14)
    return L


def to_mediapipe(Lc):
    """character space (faces -Z) -> the person faces the camera -> MediaPipe axes (y down, z away)."""
    Lcam = Lc @ Ry(math.pi).T
    out = Lcam.copy()
    out[..., 1] *= -1
    out[..., 2] *= -1
    return out


def angle_between(Ra, Rb):
    c = (np.trace(Ra.T @ Rb) - 1) / 2
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


def test_round_trip():
    rng = np.random.default_rng(7)
    T = 140
    truth = []
    world = np.zeros((T, 33, 3))
    for t in range(T):
        w = world_orients(random_pose(rng, rest=t < 15))
        truth.append(w)
        world[t] = to_mediapipe(landmarks(w))
    P = M.to_roblox_axes(world)
    P, _ = M.align_world(P, gravity_align=False)
    frames = M.part_frames(P)
    frames = M.calibrate_feet(frames, P)
    frames = M.calibrate_head(frames)
    exact = ["UpperTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
             "RightHand", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg"]
    loose = ["Head", "LeftFoot", "RightFoot"]
    report = {}
    for name in exact + loose:
        errs = [angle_between(frames[name][t], truth[t][name]) for t in range(T)]
        report[name] = (float(np.median(errs)), float(np.percentile(errs, 95)))
    # the pelvis only has to get the hip line right (its tilt is shared with the waist by design)
    hip_err = [math.degrees(math.acos(np.clip(np.dot(frames["LowerTorso"][t][:, 0], truth[t]["LowerTorso"][:, 0]),
                                              -1, 1))) for t in range(T)]
    report["LowerTorso(hip line)"] = (float(np.median(hip_err)), float(np.percentile(hip_err, 95)))
    for k, (med, p95) in report.items():
        print(f"  {k:22s} median {med:6.2f} deg   p95 {p95:6.2f} deg")
    for name in exact:
        # forearm twist is read from the hand, so a bent wrist leaks a few degrees into it
        limit = 4.0 if "LowerArm" in name else 1.0
        assert report[name][1] < limit, f"{name} error too large: {report[name]}"
    for name in loose:
        assert report[name][0] < 8.0, f"{name} error too large: {report[name]}"
    assert report["LowerTorso(hip line)"][1] < 1.0


def test_build_animation_smooth_motion():
    """A smooth squat + arm wave: the pipeline should reduce keys, report crouching and stay finite."""
    T = 90
    world = np.zeros((T, 33, 3))
    for t in range(T):
        ph = t / T * 2 * math.pi
        knee = -d(70) * (0.5 - 0.5 * math.cos(ph))
        p = random_pose(None, rest=True)
        for s in "LR":
            p[s + "UL"] = Rx(-knee * 0.9)
            p[s + "LL"] = Rx(knee * 1.9)
            p[s + "F"] = Rx(-knee)
        p["RUA"] = Rz(d(100) + d(30) * math.sin(3 * ph))
        p["RLA"] = Rx(d(60))
        w = world_orients(p)
        Lc = landmarks(w)
        world[t] = to_mediapipe(Lc)
    pose = {"world": world, "image": None, "visibility": np.ones((T, 33)), "detected": np.ones(T, bool), "fps": 30}
    anim = M.build_animation(pose, M.AnimOptions(smoothing=0.5, root_motion="inplace"))
    n = len(anim["keyTimes"])
    print(f"  keys kept: {n} of {T} frames; vertical min {min(anim['vertical']):.3f} leg lengths")
    assert 5 < n < T
    assert min(anim["vertical"]) < -0.15, "the squat should lower the hips"
    for q in anim["parts"]["RightUpperArm"]:
        assert abs(np.linalg.norm(q) - 1) < 1e-3


if __name__ == "__main__":
    print("round trip:")
    test_round_trip()
    print("smooth motion:")
    test_build_animation_smooth_motion()
    print("ALL MOTION TESTS PASSED")
