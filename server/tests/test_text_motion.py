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
