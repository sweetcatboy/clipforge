"""What the Studio plugin can build, and prompt readers that mirror the plugin's own.

catalog.json is generated from the plugin's Luau source by scripts/build_plugin.py (library effects, cutscene
templates, model types, the VFX generator's vocabulary), so the server never carries a second, drifting copy. The
readers below turn a bot's text into the exact description Studio builds, which also lets the bot be told what it
will get before Studio has built it."""
from __future__ import annotations

import json
import os
import re
from functools import lru_cache

_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "catalog.json")

# glow colours for models (same names as the plugin's ModelKit)
MODEL_COLORS = {
    "red": "#FF2A2A", "crimson": "#DC143C", "orange": "#FF7A1A", "gold": "#FFC530", "yellow": "#FFE135",
    "green": "#2EE85A", "lime": "#9BFF2E", "teal": "#14D2C0", "cyan": "#22E6FF", "blue": "#2F7BFF",
    "purple": "#9B3CFF", "violet": "#8F4DFF", "magenta": "#FF2FD3", "pink": "#FF5EB8", "white": "#F4F8FF",
    "black": "#1A1024",
}
MODEL_STYLES = [("golden", "gold"), ("gold", "gold"), ("dark", "dark"), ("shadow", "dark"), ("obsidian", "dark"),
                ("crystal", "crystal"), ("ice", "crystal"), ("glass", "crystal"), ("energy", "energy"),
                ("laser", "energy"), ("plasma", "energy"), ("light", "energy"), ("wooden", "wood"), ("wood", "wood"),
                ("iron", "steel")]
GENERATOR_MODES = ("showcase", "impact", "vortex")
QUOTES = re.compile(r'["“”]([^"“”]+)["“”]')


@lru_cache(maxsize=1)
def catalog() -> dict:
    with open(_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def _has(text: str, word: str) -> bool:
    """Luau's %f[%a]word%f[%A]: the word not glued to other letters (text is lower case)."""
    return re.search(r"(?<![a-z])" + re.escape(word) + r"(?![a-z])", text) is not None


def _text(prompt: str | None) -> str:
    from .words import normalize
    return " " + normalize(prompt) + " "


def _camel(prompt: str | None, fallback: str, limit: int = 4) -> str:
    words = [w for w in re.findall(r"[A-Za-z]+", prompt or "") if len(w) > 2][:limit]
    name = "".join(w[:1].upper() + w[1:].lower() for w in words)
    return (name or fallback)[:40]


# ------------------------------------------------------------------------------------------------- library effects
def effects(include_hidden: bool = False) -> list[dict]:
    return [e for e in catalog()["effects"] if include_hidden or not e["hidden"]]


def match_effect(prompt: str | None, prefer: str | None = None) -> tuple[dict | None, float]:
    """Best library effect for some text and its score (the same scoring as the plugin's Library.match).

    The effect's whole title said outright wins ("level up", "heal", "meteor strike"); then title words, then tags.
    `prefer` (the broad kind the words point at, e.g. "slash") breaks near-ties; combos lose ties to single effects;
    "loop"/"ambient" favours looping effects. A score of 2 or more is a real match."""
    t = _text(prompt)
    wants_loop = _has(t, "loop") or _has(t, "looping") or _has(t, "ambient")
    best, best_score = None, 0.0
    for e in effects():
        title = e["title"].lower()
        score = 0.0
        if _has(t, title) or _has(t, title.replace(" ", "")):
            score += 8
        title_words = set(re.findall(r"[a-z]+", title))
        for w in title_words:
            if len(w) > 2 and _has(t, w):
                score += 2.5
        for w in set(re.findall(r"[a-z]+", e["tags"])) - title_words:
            if len(w) > 2 and _has(t, w):
                score += 2 if len(w) > 5 else 1
        if prefer and e["id"] == prefer:
            score += 1
        if e["combo"] and score < 8:
            score -= 0.5
        if wants_loop and e["ambient"]:
            score += 2
        if score > best_score:
            best, best_score = e, score
    return best, best_score


def effect_words(e: dict) -> set[str]:
    return set(re.findall(r"[a-z]+", (e["title"] + " " + e["tags"]).lower()))


# ----------------------------------------------------------------------------------------------- VFX generator
def generate_desc(prompt: str, seed: int = 1, mode: str | None = None, chromatic: bool | None = None) -> dict:
    """A showcase/attack description for the plugin's Generator (same reading as Generator.fromPrompt)."""
    text = _text(prompt)
    h = lambda w: _has(text, w)  # noqa: E731
    d: dict = {"frames": [], "energy": [], "atmos": [], "seed": int(seed or 1), "prompt": prompt}
    if any(h(w) for w in ("black hole", "blackhole", "singularity", "vortex", "void")):
        d["mode"] = "vortex"
    elif any(h(w) for w in ("impact", "slam", "attack", "explosion", "strike", "punch", "ultimate", "burst", "smash")):
        d["mode"] = "impact"
    else:
        d["mode"] = "showcase"
    if h("wireframe") or h("wire") or h("outline"):
        d["hero"] = "wirecube"
    elif h("cube") or h("box") or h("tesseract") or h("artifact"):
        d["hero"] = "cube"
    elif h("crystal") or h("gem"):
        d["hero"] = "crystal"
    elif h("orb") or h("sphere") or h("core") or h("sun"):
        d["hero"] = "orb"
    else:
        d["hero"] = "cube"
    gen = catalog()["generator"]
    for w in gen["want"]:
        if any(h(x) for x in w["words"]):
            d[w["group"]].append(w["key"])
    if mode in GENERATOR_MODES:
        d["mode"] = mode
    if d["mode"] == "showcase":  # a showcase with nothing asked still gets a full composition
        if not d["frames"]:
            d["frames"].append("rings")
        if not d["atmos"]:
            d["atmos"] += ["stars", "flakes"]
        if not d["energy"]:
            d["energy"].append("rays")
    palette = next((th["palette"] for th in gen["themes"] if any(h(w) for w in th["words"])), None)
    if palette:
        d["palette"] = palette
    d["chromatic"] = bool(h("chromatic") or h("rainbow") or h("prism") or h("opus") or palette == "mono"
                          or (d["mode"] == "impact" and not palette))
    if chromatic is not None:
        d["chromatic"] = bool(chromatic)
    if h("big") or h("huge") or h("giant"):
        d["scale"] = 1.5 if d["mode"] == "impact" else 2
    elif h("small") or h("tiny"):
        d["scale"] = 0.8
    if h("long") or h("idle") or h("showcase"):
        d["length"] = 8
    d["name"] = _camel(prompt, "Generated")
    return d


def describe_generate(d: dict) -> str:
    bits = [d["mode"]]
    if d["mode"] == "showcase":
        bits.append({"wirecube": "wireframe cube", "cube": "glowing cube"}.get(d.get("hero"), d.get("hero") or "cube"))
    extras = d.get("frames", []) + d.get("energy", []) + d.get("atmos", [])
    if extras:
        bits.append(", ".join(extras))
    if d.get("palette"):
        bits.append(d["palette"] + " palette")
    if d.get("chromatic"):
        bits.append("chromatic fringes")
    return " · ".join(bits)


# --------------------------------------------------------------------------------------------------- cutscenes
def cutscene_from_prompt(prompt: str, who: str = "Target", name: str | None = None) -> dict:
    """Template + lines + effect for the plugin's Cutscene.template (same choice as Cutscene.fromPrompt)."""
    text = _text(prompt)
    best, best_score = "intro", 0
    for t in catalog()["cutscenes"]:
        s = sum(len(w) for w in re.findall(r"[a-z]+", t["tags"]) if _has(text, w))
        if s > best_score:
            best, best_score = t["id"], s
    lines = [q.strip() for q in QUOTES.findall(prompt or "") if q.strip()]
    e, score = match_effect(prompt)
    title = next((t["title"] for t in catalog()["cutscenes"] if t["id"] == best), best)
    out = {"type": "cutscene", "template": best, "templateTitle": title, "who": who or "Target", "lines": lines,
           "prompt": prompt, "name": name or (title.replace(" ", "") if not lines else _camel(prompt, "Cutscene"))}
    if e and score >= 2:
        out["effect"] = e["id"]
    return out


# ------------------------------------------------------------------------------------------------------ models
def model_from_prompt(prompt: str, name: str | None = None) -> dict:
    """Weapon/prop settings for the plugin's ModelKit (same reading as ModelKit.parse; the first colour named wins)."""
    text = _text(prompt)
    style_words = {w for w, _ in MODEL_STYLES}
    best, best_score = "sword", 0
    for with_style in (False, True):  # style words ("crystal staff") only pick the type when nothing else does
        for t in catalog()["models"]:
            score = sum(len(w) for w in re.findall(r"[a-z]+", t["tags"])
                        if (with_style or w not in style_words)
                        and re.search(r"(?<![a-z])" + re.escape(w) + r"s?(?![a-z])", text))
            if score > best_score:
                best, best_score = t["id"], score
        if best_score:
            break
    style = next((s for w, s in MODEL_STYLES if _has(text, w)), "steel")
    found = sorted((m.start(), c) for c in MODEL_COLORS for m in [re.search(r"(?<![a-z])" + c + r"(?![a-z])", text)]
                   if m)
    glow = MODEL_COLORS[found[0][1]] if found else None
    if not glow and any(w in text for w in ("glow", "magic", "enchant")):
        glow = "#7C5CFF"
    scale = 1.0
    for w, s in (("tiny", 0.6), ("small", 0.8), ("big", 1.3), ("large", 1.3), ("huge", 1.6), ("giant", 1.8)):
        if _has(text, w):
            scale = s
    kind = next((t for t in catalog()["models"] if t["id"] == best), {})
    # `type` is the ModelKit type id, exactly what the plugin's ModelKit.build reads
    return {"type": best, "kind": kind.get("kind"), "style": style, "glow": glow, "scale": scale, "prompt": prompt,
            "name": name or _camel(prompt, kind.get("title", "Model").replace(" ", ""))}


def describe_model(m: dict) -> str:
    title = next((t["title"] for t in catalog()["models"] if t["id"] == m["type"]), m["type"])
    bits = [m["style"], title.lower()]
    if m.get("glow"):
        bits.append("glow " + m["glow"])
    if m.get("scale", 1) != 1:
        bits.append(f"x{m['scale']:g} size")
    return " ".join(bits[:2]) + (" · " + " · ".join(bits[2:]) if len(bits) > 2 else "")


def summary() -> dict:
    """Everything a bot can ask for, for /api/presets and the MCP presets tool."""
    c = catalog()
    return {
        "effects": [{k: e[k] for k in ("id", "title", "category", "tags")} | ({"loop": True} if e["ambient"] else {})
                    for e in effects()],
        "generator": {"modes": list(GENERATOR_MODES), "heroes": ["cube", "wirecube", "crystal", "orb"],
                      "add": {g: [w["key"] for w in c["generator"]["want"] if w["group"] == g]
                              for g in ("frames", "energy", "atmos")},
                      "palettes": [t["palette"] for t in c["generator"]["themes"]],
                      "examples": ["golden glowing cube with light wings", "galaxy wireframe cube with orbit rings",
                                   "blue black hole with floating rocks", "white chromatic impact",
                                   "green crystal heart with leaves"]},
        "cutscenes": [{k: t[k] for k in ("id", "title")} for t in c["cutscenes"]],
        "models": [{k: t[k] for k in ("id", "title", "kind")} for t in c["models"]],
        "animations": _moves(),
    }


def _moves() -> list[dict]:
    """The text animation move library (no video needed): attacks, locomotion, reactions, emotes and combos."""
    from . import text_motion
    return [{k: m[k] for k in ("id", "title", "category", "loop")} for m in text_motion.catalog()]
