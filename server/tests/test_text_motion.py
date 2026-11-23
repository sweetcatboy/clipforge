"""Text -> animation: every move in the library bakes to clean data (unit quaternions, rising key times, hits inside
the clip, no pops between frames), prompts are read into moves / speed / side / sequences, the router turns free-form
messages into the right outputs, and words go through a JobStore (and the no-job preview) end to end.
Run:  python tests/test_text_motion.py"""
import os
import sys
import tempfile

import numpy as np

os.environ["CLIPFORGE_DATA"] = tempfile.mkdtemp(prefix="clipforge-test-")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from clipforge import router, text_motion  # noqa: E402
from clipforge.motion import R15_PARTS  # noqa: E402


def _max_step(d):
    """Largest rotation of any part between neighbouring 30 fps frames (degrees per frame)."""
    kt, worst = d["keyTimes"], 0.0
    for qs in d["parts"].values():
        q = np.array(qs)
        for i in range(1, len(q)):
            frames = max(round((kt[i] - kt[i - 1]) * 30), 1)
            ang = 2 * np.degrees(np.arccos(min(1.0, abs(float(np.dot(q[i], q[i - 1]))))))
            worst = max(worst, ang / frames)
    return worst


def test_every_move_bakes_clean():
    ids = [m["id"] for m in text_motion.catalog()]
    assert len(ids) >= 40, len(ids)
    for mid in ids:
        d = text_motion.bake(mid)
        kt = d["keyTimes"]
        assert kt[0] == 0 and all(b > a for a, b in zip(kt, kt[1:])), mid
        assert abs(kt[-1] - d["duration"]) < 0.05 and d["duration"] > 0.3, (mid, d["duration"])
        assert set(d["parts"]) == set(R15_PARTS), mid
        for part, qs in d["parts"].items():
            assert len(qs) == len(kt), (mid, part)
            n = np.linalg.norm(np.array(qs), axis=1)
            assert np.all(np.abs(n - 1) < 1e-3), (mid, part)
        assert len(d["root"]) == len(kt) and len(d["airborne"]) == len(kt)
        for m in d["markers"]:
            assert m["name"] == "Hit" and 0 <= m["t"] <= d["duration"] and m["t"] in kt, (mid, m)
        # strikes are fast, but nothing may jump half a turn in one frame (a pop or a flip)
        assert _max_step(d) < 130, (mid, _max_step(d))
        assert d["priority"] in ("Idle", "Movement", "Action"), mid


def test_attacks_have_hits_and_holds_do_not_pop():
    for mid in ("jab", "cross", "hook", "uppercut", "kick", "slash", "thrust", "overhead"):
        d = text_motion.bake(mid)
        assert d["markers"], mid
        assert 0.1 <= d["markers"][0]["t"] <= 0.45, (mid, d["markers"])
        assert 0.4 <= d["duration"] <= 0.95, (mid, d["duration"])
    # the hold after a contact eases out instead of snapping back to the stance
    d = text_motion.bake("cross")
    assert _max_step(d) < 100, _max_step(d)


def test_describe_prompts():
    d = text_motion.describe("jab then cross then hook")
    assert d["moves"] == ["jab", "cross", "hook"], d
    assert text_motion.describe("fast sword slash")["speed"] > 1
    assert text_motion.describe("slow wave")["speed"] < 1
    assert text_motion.describe("left hook")["mirror"] is False  # the hook's own lead hand
    assert text_motion.describe("right hook")["mirror"] is True
    assert text_motion.describe("looping idle")["loop"] is True
    assert text_motion.match_move("backflip")[0] == "backflip"
    assert text_motion.match_move("kamehameha")[0] == "beam"
    a = text_motion.from_prompt("heavy overhead slam")
    assert a["moves"] == ["overhead"] and a["markers"], a["moves"]
    combo = text_motion.from_prompt("punch combo")
    assert combo["moves"] == ["jab", "cross", "hook"] and len(combo["markers"]) == 3


def test_router():
    cases = {
        "fire punch": ("animation", "vfx"), "make me a backflip": ("animation",), "chain lightning": ("vfx",),
        "coin burst": ("vfx",), "kamehameha": ("animation", "vfx"), "glowing purple katana": ("model",),
        "boss intro cutscene": ("cutscene",), "golden glowing cube with light wings": ("generate",),
        "cheer with confetti": ("animation", "vfx"), "huge purple lightning slash": ("vfx",),
        "wave hello": ("animation",),
    }
    for text, want in cases.items():
        p = router.plan(text)
        got = tuple(k for k in ("animation", "vfx", "generate", "model", "cutscene") if p[k])
        assert got == want, (text, got, p["reason"])
    p = router.plan("glowing katana", kind="animation")  # an explicit kind wins
    assert p["animation"] and not p["model"]


def test_router_regressions():
    """Phrasings that were misread during bug testing."""
    cases = {
        "lightning kick": ("animation", "vfx"), "kick with lightning": ("animation", "vfx"),  # element-named effect
        "cross slash": ("vfx",),           # the longer title (the Cross Slash effect) beats the Cross punch
        "meteor strike": ("vfx",),         # an effect title, not the meteor model
        "throw a fireball": ("animation", "vfx"), "bow with petals": ("animation", "vfx"),
        "fireworks": ("vfx",), "nuke": ("vfx",), "explode": ("vfx",), "snow": ("vfx",),
        "punching": ("animation", "vfx"), "surprise me": ("generate",),  # like "punch": the move and its impact
        'boss intro "You dare?"': ("cutscene",), 'npc says "hello"': ("cutscene",), "victory pose": ("animation",),
    }
    for text, want in cases.items():
        p = router.plan(text)
        got = tuple(k for k in ("animation", "vfx", "generate", "model", "cutscene") if p[k])
        assert got == want, (text, got, p["reason"])
    # unclear messages ask instead of building something random
    for text in ("asdfghjkl", "the", "1234", "make a vfx", "make an animation", "one two", "🔥👊"):
        p = router.plan(text)
        assert not any(p[k] for k in ("animation", "vfx", "generate", "model", "cutscene")), (text, p["reason"])
        assert "Nothing to make" in p["reason"]
    # one punch is one punch; combos need the word
    assert text_motion.describe("punch")["moves"] == ["cross"]
    assert text_motion.describe("punch combo")["moves"] == ["punchcombo"]
    assert text_motion.describe("fighting idle")["moves"] == ["fightidle"]
    assert text_motion.describe("jab cross hook uppercut")["moves"] == ["jab", "cross", "hook", "uppercut"]
    assert text_motion.describe("super saiyan")["moves"] == ["charge"]
    assert text_motion.describe("triple jump")["moves"] == ["jump", "jump", "jump"]
    assert text_motion.describe("double slash")["moves"] == ["slash", "slash"]
    assert text_motion.describe("jab x3")["moves"] == ["jab", "jab", "jab"]
    assert text_motion.describe("dance twice")["moves"] == ["dance"]  # a looping move is not repeated


def test_requests_from_a_real_session():
    """What a user typed in the Create tab while testing 1.2.0."""
    from clipforge.jobs import JobStore
    store = JobStore()
    pv = store.preview({"prompt": "create me a animation where a player turns into a blackhole"})
    r = pv["result"]
    assert r["animation"]["moves"] == ["charge"] and r["vfx"]["base"] == "blackhole", pv["message"]
    assert r["ability"]["marker"] == "Hit" and len(r["ability"]["at"]) == 1
    pv = store.preview({"prompt": "create me a animation where they clap then summon a blackhole", "kind": "both"})
    r = pv["result"]
    assert r["animation"]["moves"] == ["clap", "cast"], r["animation"]["moves"]
    # a black hole is a one-off: it fires once, on the last hit, through its own marker, in front
    assert r["ability"] == {"marker": "Fx", "attach": "Front", "at": [r["animation"]["markers"][-2]["t"]]} or (
        r["ability"]["marker"] == "Fx" and len(r["ability"]["at"]) == 1 and r["ability"]["attach"] == "Front"), r["ability"]
    assert sum(1 for m in r["animation"]["markers"] if m["name"] == "Fx") == 1
    # per-hit effects keep firing on every hit
    pv = store.preview({"prompt": "jab cross hook with sparks"})
    assert pv["result"]["ability"]["marker"] == "Hit" and len(pv["result"]["ability"]["at"]) == 3
    # 'both' with no move in the library still makes the effect, and says so
    pv = store.preview({"prompt": "a swirling black hole", "kind": "both"})
    assert pv["result"]["vfx"] and not pv["result"]["animation"] and "only the effect" in pv["message"], pv["message"]
    # an effect-only request that names a move gets that move's own effect (a dodge's dash burst)
    pv = store.preview({"prompt": "dodge", "kind": "vfx"})
    assert pv["result"]["vfx"]["base"] == "dash", pv["result"]["vfx"]["base"]
    # pressing Generate twice makes one job
    a = store.create({"prompt": "backflip", "client": "studio"})
    b = store.create({"prompt": "backflip", "client": "studio"})
    c = store.create({"prompt": "backflip", "client": "discord"})
    assert a.id == b.id and a.id != c.id


def test_clip_hits_and_ability_links():
    """Video animations get Hit markers where a hand or foot stops sharply; an animation and an effect made together
    always become an ability (every hit for per-hit effects, one Fx for a one-off, the effect peak with no hits)."""
    from clipforge.jobs import JobStore
    from clipforge.motion import detect_hits
    fps, T = 30, 90
    P = np.zeros((T, 33, 3))
    P[:, 23], P[:, 24] = [-0.1, 0, 0], [0.1, 0, 0]
    x = np.zeros(T)
    for f in range(T):  # wind back, snap forward for 4 frames, stop dead at frame 40
        x[f] = 0.1 if f < 30 else (0.1 - 0.02 * (f - 30) if f < 36 else (-0.02 + 0.17 * (f - 36) if f < 40 else x[39]))
    P[:, 16, 2] = -x
    assert detect_hits(P, fps) == [40], detect_hits(P, fps)
    P[:, 16, 2] = -0.1 + 0.05 * np.sin(np.arange(T) / 10)  # a gentle wave has no contact
    assert detect_hits(P, fps) == []

    anim = {"duration": 2.0, "markers": [{"name": "Hit", "t": 0.5}, {"name": "Hit", "t": 1.2}]}
    r = {"animation": dict(anim), "vfx": {"base": "punch"}}
    assert JobStore._link_ability(r, "Front") and r["ability"] == {"marker": "Hit", "attach": "Front", "at": [0.5, 1.2]}
    r = {"animation": dict(anim), "vfx": {"base": "explosion", "analysis": {"timing": {"peak": 1.1}}}}
    assert JobStore._link_ability(r) and r["ability"]["marker"] == "Fx" and r["ability"]["at"] == [1.2]
    assert {"name": "Fx", "t": 1.2} in r["animation"]["markers"]
    r = {"animation": {"duration": 2.0, "markers": []}, "vfx": {"base": "aura", "analysis": {"timing": {"peak": 0.9}}}}
    assert JobStore._link_ability(r) and r["ability"] == {"marker": "", "attach": "Front", "at": [0.9]}
    r = {"animation": {"duration": 2.0, "markers": []}, "vfx": {"base": "aura"}}
    assert not JobStore._link_ability(r)  # nothing to time it by: the plugin falls back to 40 % in


def test_options_are_parsed_strictly():
    assert text_motion.from_prompt("jab", mirror="false")["moves"] == ["jab"]
    assert text_motion.from_prompt("wave", loop="true")["loop"] is True
    for bad in ({"speed": "fast"}, {"speed": -1}, {"speed": float("nan")}, {"mirror": "maybe"}):
        try:
            text_motion.from_prompt("jab", **bad)
        except ValueError:
            continue
        raise AssertionError(f"accepted {bad}")
    assert "punch" in router.vfx_prompt_for("fire punch", "jab") or "fire" in router.vfx_prompt_for("fire punch", "jab")


def test_word_jobs_and_preview():
    from clipforge.jobs import JobStore
    store = JobStore()

    def run(payload):
        job = store.create(payload)
        job = store.wait_for(job.id, 20)
        assert job.status == "done", (payload, job.status, job.error)
        return job, store.result(job.id)

    job, res = run({"prompt": "fire punch"})
    assert job.kind == "auto" and res["animation"] and res["vfx"], job.message
    assert res["ability"]["marker"] == "Hit" and res["ability"]["at"], res["ability"]
    assert "ability" in job.message
    job, res = run({"prompt": "backflip", "kind": "animation", "options": {"speed": 1.2}})
    assert res["animation"]["moves"] == ["backflip"] and not res["vfx"]
    job, res = run({"prompt": "glowing purple katana"})
    assert res["model"]["type"] == "katana"
    job, res = run({"prompt": "boss intro \"You dare?\""})
    assert res["cutscene"]["template"] == "intro" and res["cutscene"]["lines"] == ["You dare?"]
    before = len(store.list(limit=1000))
    pv = store.preview({"prompt": "kamehameha"})
    assert pv["plan"]["animation"] and pv["plan"]["vfx"] and pv["result"]["animation"]["moves"] == ["beam"]
    assert len(store.list(limit=1000)) == before  # a preview queues nothing
    try:
        store.preview({"prompt": ""})
    except ValueError:
        pass
    else:
        raise AssertionError("empty preview accepted")


def test_mcp_make_tool():
    from clipforge import mcp_server
    from clipforge.jobs import JobStore
    backend = mcp_server.LocalBackend(JobStore())
    names = {t["name"] for t in mcp_server.TOOLS}
    assert {"clipforge_make", "clipforge_animation_from_prompt"} <= names
    out = mcp_server._call(backend, "clipforge_make", {"message": "fire punch", "preview": True})
    assert out["plan"]["animation"] and out["plan"]["vfx"] and "ability" in out["would_make"], out
    out = mcp_server._call(backend, "clipforge_animation_from_prompt", {"prompt": "uppercut", "effect": True})
    assert out["status"] == "done" and out["summary"]["animation"] and out["summary"]["vfx"], out
    presets = backend.presets()
    assert any(m["id"] == "slash" for m in presets["animations"])


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("ok", name)
    print("all text motion tests passed")
