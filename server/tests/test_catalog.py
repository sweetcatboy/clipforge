"""Prompt readers and prompt-only jobs: library effect matching (with element recolouring), generated-VFX
descriptions, models, cutscene templates, and the generate / model / cutscene job kinds end to end through a JobStore
in a throwaway data folder. Run:  python tests/test_catalog.py"""
import os
import sys
import tempfile

os.environ["CLIPFORGE_DATA"] = tempfile.mkdtemp(prefix="clipforge-test-")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from clipforge import catalog  # noqa: E402
from clipforge.prompts import config_from_prompt  # noqa: E402


def test_catalog_loaded():
    c = catalog.catalog()
    assert len(catalog.effects()) >= 55, len(catalog.effects())
    assert {t["id"] for t in c["cutscenes"]} >= {"intro", "victory", "reveal", "ability", "flyover", "dialogue", "defeat"}
    assert {"sword", "katana", "staff", "shield", "portal"} <= {t["id"] for t in c["models"]}
    s = catalog.summary()
    assert s["generator"]["modes"] == ["showcase", "impact", "vortex"] and s["effects"] and s["models"]


def test_effect_matching():
    expect = {
        "huge purple lightning slash": "slash", "small holy heal": "heal", "tornado": "tornado",
        "fast red fireball that explodes": "projectile", "level up sparkle": "levelup", "dark portal": "darkportal",
        "blue shield bubble": "shield", "meteor strike": "meteor", "double jump": "doublejump", "punch": "punch",
        "ice spikes": "icespikes", "fire loop": "campfire", "black hole": "blackhole", "kamehameha beam": "beam",
    }
    for text, base in expect.items():
        cfg = config_from_prompt(text)
        assert cfg["base"] == base, (text, cfg["base"])
    # follow-up explosion keeps working with library bases
    assert [p["base"] for p in config_from_prompt("sword slash that explodes")["parts"]] == ["slash", "explosion"]
    assert [p["base"] for p in config_from_prompt("fast red fireball that explodes")["parts"]] == ["projectile",
                                                                                                    "explosion"]


def test_element_colours():
    assert config_from_prompt("tornado")["palette"] is None  # designed colours kept
    assert config_from_prompt("ice spikes")["palette"] is None  # ice is its own element
    assert config_from_prompt("poison cloud")["palette"] is None  # "poison" names its own colour
    assert config_from_prompt("black hole")["palette"] is None
    fire_tornado = config_from_prompt("fire tornado")["palette"]
    assert fire_tornado and fire_tornado["primary"].upper().startswith("#FF"), fire_tornado
    icy = config_from_prompt("ice slam")["palette"]
    assert icy and int(icy["primary"][5:7], 16) > 200, icy  # blue-dominant
    assert config_from_prompt("red tornado")["palette"]["primary"] == "#FF2A2A"


def test_generate_desc():
    d = catalog.generate_desc("golden glowing cube with light wings")
    assert d["mode"] == "showcase" and d["hero"] == "cube" and "wings" in d["frames"] and d["palette"] == "golden"
    d = catalog.generate_desc("galaxy wireframe cube with orbit rings and nebula")
    assert d["hero"] == "wirecube" and "rings" in d["frames"] and "nebula" in d["atmos"] and d["palette"] == "galaxy"
    d = catalog.generate_desc("blue black hole with floating rocks")
    assert d["mode"] == "vortex" and d["palette"] == "abyss"
    d = catalog.generate_desc("white chromatic impact")
    assert d["mode"] == "impact" and d["chromatic"] and d["palette"] == "mono"
    d = catalog.generate_desc("something nice")  # nothing asked: still a full showcase
    assert d["mode"] == "showcase" and d["frames"] and d["atmos"] and d["energy"]
    d = catalog.generate_desc("green crystal", mode="impact", chromatic=False)
    assert d["mode"] == "impact" and d["chromatic"] is False
    assert catalog.describe_generate(catalog.generate_desc("golden cube with wings")).startswith("showcase")


def test_models():
    m = catalog.model_from_prompt("glowing purple katana")
    assert m["type"] == "katana" and m["glow"] == "#9B3CFF" and m["style"] == "steel", m
    m = catalog.model_from_prompt("golden greatsword")
    assert m["type"] == "greatsword" and m["style"] == "gold", m
    m = catalog.model_from_prompt("huge wooden hammer")
    assert m["type"] == "hammer" and m["style"] == "wood" and m["scale"] == 1.6, m
    m = catalog.model_from_prompt("crystal staff with a blue and red glow")
    assert m["type"] == "staff" and m["style"] == "crystal" and m["glow"] == "#2F7BFF", m  # first colour named
    assert "katana" in catalog.describe_model(catalog.model_from_prompt("dark katana"))


def test_cutscene_prompts():
    c = catalog.cutscene_from_prompt('boss intro with "You dare challenge me?"', who="Boss")
    assert c["template"] == "intro" and c["lines"] == ["You dare challenge me?"] and c["who"] == "Boss", c
    c = catalog.cutscene_from_prompt("victory celebration with confetti")
    assert c["template"] == "victory" and c.get("effect") == "confetti", c
    assert catalog.cutscene_from_prompt("map flyover of the castle")["template"] == "flyover"
    c = catalog.cutscene_from_prompt("“Hello there” “General” dialogue")  # phone-style quotes
    assert c["template"] == "dialogue" and c["lines"] == ["Hello there", "General"], c


def test_prompt_jobs():
    from clipforge.jobs import JobStore
    store = JobStore()

    def run(payload):
        job = store.create(payload)
        job = store.wait_for(job.id, 20)
        assert job.status == "done", (payload, job.status, job.error)
        return job, store.result(job.id)

    job, res = run({"kind": "generate", "prompt": "golden glowing cube with light wings", "options": {"seed": 3}})
    g = res["vfx"]["generate"]
    assert g["mode"] == "showcase" and g["seed"] == 3 and "wings" in g["frames"] and res["vfx"]["name"]
    assert "showcase" in job.message
    job, res = run({"kind": "model", "prompt": "glowing purple katana", "options": {"style": "dark"}})
    assert res["model"]["type"] == "katana" and res["model"]["style"] == "dark", res["model"]
    assert job.summary["model"]["type"] == "katana"
    job, res = run({"kind": "cutscene", "prompt": 'victory "We did it!"', "options": {"who": "Hero"}})
    assert res["cutscene"]["template"] == "victory" and res["cutscene"]["who"] == "Hero"
    assert res["cutscene"]["lines"] == ["We did it!"]
    job, res = run({"prompt": "small holy heal"})  # default kind for a prompt is vfx
    assert res["vfx"]["base"] == "heal"
    for bad in ({"kind": "generate", "source": "x.mp4"}, {"kind": "model"}, {"kind": "nope", "prompt": "x"},
                {"kind": "auto"}):
        try:
            store.create(bad)
        except ValueError:
            continue
        raise AssertionError(f"accepted {bad}")
    bad = store.create({"kind": "model", "prompt": "sword", "options": {"style": "plaid"}})
    assert store.wait_for(bad.id, 10).status == "failed"


def test_new_effects_match():
    expect = {"coin burst": "coinburst", "chain lightning": "chainlightning", "falling leaves": "fallingleaves",
              "smoke bomb": "smokebomb", "egg hatch": "egghatch", "time stop": "timestop", "loot beam": "lootbeam",
              "spin slash": "spinslash", "earthquake": "earthquake", "boss spawn": "bossspawn",
              "cherry blossoms": "petals", "muzzle flash": "muzzleflash"}
    for text, base in expect.items():
        assert config_from_prompt(text)["base"] == base, (text, config_from_prompt(text)["base"])
    assert len(catalog.effects()) == 100


def test_claim_pause_and_build_errors():
    from clipforge.jobs import JobStore
    store = JobStore()
    job = store.create({"kind": "model", "prompt": "sword"})
    assert store.wait_for(job.id, 10).status == "done"
    for _ in range(3):  # a Studio that keeps failing to build it
        ok, _, _ = store.claim(job.id, "A")
        assert ok
        ok, _, _ = store.claim(job.id, "A", release=True, error="String too long")
        assert ok
    ok, j, why = store.claim(job.id, "A")
    assert not ok and "Paused" in why, why  # an old plugin that retries on every poll stops here
    assert j.buildError == "String too long"
    ok, _, _ = store.claim(job.id, "A", force=True)  # a person pressing Build here can always retry
    assert ok
    store.mark_delivered(job.id, {"studio": "A"})
    assert store.get(job.id).buildError is None


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("ok", name)
    print("all catalog tests passed")
