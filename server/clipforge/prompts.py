"""Text prompt -> effect config ("a huge purple lightning slash", "small holy heal", "fast red fireball")."""
from __future__ import annotations

import colorsys
import re

from . import catalog
from .vfx_analyze import ARCHETYPES, _from_hsv, _hex

KEYWORDS = {
    "slash": ["slash", "sword", "cut", "blade", "katana", "swing", "crescent", "slice", "cleave", "scythe"],
    "impact": ["impact", "slam", "punch", "hit", "smash", "ground", "stomp", "shockwave", "quake", "kick", "land"],
    "explosion": ["explosion", "explode", "boom", "blast", "bomb", "nuke", "detonat", "grenade", "kaboom"],
    "aura": ["aura", "charge", "power up", "powerup", "transform", "buff", "rage", "super saiyan", "ki ", "awaken"],
    "beam": ["beam", "laser", "kamehameha", "ray", "lance", "cannon", "breath"],
    "lightning": ["lightning", "thunder", "electric", "shock", "zap", "volt", "storm", "plasma", "tesla"],
    "projectile": ["projectile", "fireball", "orb", "bullet", "shot", "missile", "throw", "ball", "arrow", "bolt"],
    "fire": ["fire", "flame", "burn", "inferno", "blaze", "magma", "lava", "ember", "pyro"],
    "ice": ["ice", "frost", "freeze", "snow", "water", "splash", "wave", "aqua", "glacier", "crystal", "cryo"],
    "dark": ["dark", "void", "portal", "shadow", "black hole", "rift", "abyss", "curse", "domain", "demon", "evil"],
    "holy": ["holy", "light", "heal", "divine", "angel", "bless", "sparkle", "star", "teleport", "magic", "revive"],
}

COLORS = {
    "red": "#FF2A2A", "crimson": "#DC143C", "blood": "#B0001E", "scarlet": "#FF2400", "orange": "#FF7A1A",
    "amber": "#FFB000", "gold": "#FFC530", "golden": "#FFC530", "yellow": "#FFE135", "lime": "#9BFF2E",
    "green": "#2EE85A", "toxic": "#7CFF00", "poison": "#8CFF3A", "emerald": "#18C77A", "teal": "#14D2C0",
    "cyan": "#22E6FF", "aqua": "#2AD8FF", "sky": "#5CC8FF", "blue": "#2F7BFF", "azure": "#2F95FF",
    "navy": "#1430A8", "indigo": "#5A3CFF", "purple": "#9B3CFF", "violet": "#8F4DFF", "magenta": "#FF2FD3",
    "pink": "#FF5EB8", "rose": "#FF4F8B", "sakura": "#FF9CCB", "white": "#F4F8FF", "silver": "#CFD8E6",
    "black": "#1A1024", "dark": "#2A1240", "rainbow": "#FF4FD8",
}
# element words recolour an effect that is not already that element ("ice slam", "fire tornado", "lightning slash");
# `native` words mark effects that already are ("explosion" is fire, "frost burst" is ice)
ELEMENTS = [
    {"words": ["ice", "frost", "frozen", "freeze", "cryo", "snow", "glacier"], "native": ["cold", "crystal", "snowfall"],
     "colors": ("#5CC8FF", "#BDEBFF")},
    {"words": ["fire", "flame", "flaming", "inferno", "lava", "magma", "burning", "blaze"],
     "native": ["fireball", "explosion", "eruption", "flamethrower", "campfire", "bonfire", "torch", "embers", "volcano",
                "meteor"], "colors": ("#FF6418", "#FFB238")},
    {"words": ["electric", "lightning", "thunder", "shock", "plasma", "volt"], "native": ["zap", "bolt", "crackle"],
     "colors": ("#6FB6FF", "#B98CFF")},
    {"words": ["holy", "divine", "angel", "heaven", "celestial"], "native": ["radiant", "bless", "judgment"],
     "colors": ("#FFC530", "#FFF0A8")},
    {"words": ["water", "aqua", "ocean", "tidal"], "native": ["splash", "liquid", "rain"],
     "colors": ("#2AD8FF", "#5CC8FF")},
    {"words": ["nature", "leaf", "leaves", "forest", "plant"], "native": ["fireflies"], "colors": ("#2EE85A", "#9BFF2E")},
    {"words": ["wind", "air"], "native": ["gust", "tornado", "cyclone", "breeze", "whirlwind"],
     "colors": ("#CFEFFF", "#FFFFFF")},
]

THEMES = {  # archetype -> default palette when the prompt names no colour
    "slash": ("#FFFFFF", "#7FD6FF", "#C9F0FF", "#0E2A55"),
    "impact": ("#FFF6E6", "#FF7A2E", "#FFB15C", "#3A1606"),
    "explosion": ("#FFF6EA", "#FF6A1C", "#FFC04D", "#2B0E04"),
    "aura": ("#F4F8FF", "#4FA8FF", "#9C6BFF", "#0B1E4A"),
    "beam": ("#FFF4FF", "#C15CFF", "#5CD6FF", "#22063D"),
    "lightning": ("#F4F7FF", "#6FB6FF", "#B98CFF", "#0B1640"),
    "projectile": ("#FFF6E8", "#FF8A2E", "#FFD15C", "#3A1606"),
    "fire": ("#FFF1D6", "#FF6418", "#FFB238", "#3B0A04"),
    "ice": ("#E8F6FF", "#5CC8FF", "#BDEBFF", "#0C2E66"),
    "dark": ("#FFFFFF", "#8A2BFF", "#FF2F9E", "#0A0014"),
    "holy": ("#FFF6E6", "#FFC530", "#FFF0A8", "#4A2A00"),
}


def _hsv_of(hexstr):
    r, g, b = (int(hexstr[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return colorsys.rgb_to_hsv(r, g, b)


def palette_from(primary_hex, secondary_hex=None, dark=False):
    h, s, v = _hsv_of(primary_hex)
    core = _from_hsv(h, 0.08 if s > 0.15 else 0.0, 1.0)
    body = _from_hsv(h, max(s, 0.55) if s > 0.12 else s, max(v, 0.85))
    if secondary_hex:
        h2, s2, v2 = _hsv_of(secondary_hex)
        sec = _from_hsv(h2, max(s2, 0.5), max(v2, 0.8))
    else:
        sec = _from_hsv(h + 0.04, min(1, s * 0.7 + 0.1), 1.0)
    deep = _from_hsv(h + 0.02, min(1, max(s, 0.6) * 1.1), 0.12 if dark else 0.2)
    return {"core": _hex(core), "primary": _hex(body), "secondary": _hex(sec), "deep": _hex(deep)}


def config_from_prompt(prompt: str, name: str | None = None) -> dict:
    text = " " + (prompt or "").lower() + " "
    scores = {k: 0 for k in KEYWORDS}
    for arch, words in KEYWORDS.items():
        for w in words:
            if w in text:
                scores[arch] += 2 if len(w) > 4 else 1
    archetype = max(scores, key=scores.get) if any(scores.values()) else "impact"
    # "fireball" is a projectile even though it says fire; "dark slash" is a slash in dark colours
    if scores["projectile"] and scores["fire"] and "fireball" in text:
        archetype = "projectile"
    for primary_kind in ("slash", "beam", "projectile", "impact", "explosion", "aura", "lightning"):
        if scores[primary_kind] and archetype in ("dark", "holy", "fire", "ice") and scores[primary_kind] >= 1:
            archetype = primary_kind
            break

    # a specific effect from the plugin's library ("heal", "tornado", "meteor", "level up"...) beats a broad archetype.
    # A follow-up clause ("... that explodes", "... into a slam") adds a second part below; it must not pick the first.
    follow_at = re.search(r"\b(and|then|into|with|that)\b.*\b(explo|boom|blast|impact|slam)", text)
    main = text[:follow_at.start()] if follow_at and follow_at.start() > 0 else prompt
    entry, lib_score = catalog.match_effect(main, prefer=ARCHETYPES[archetype][0])
    use_lib = entry is not None and lib_score >= 2

    found = [(text.find(" " + c), c) for c in COLORS if re.search(r"\b" + re.escape(c) + r"\b", text)]
    found = [c for _, c in sorted(found)]
    dark = "dark" in text or "black" in text or "void" in text
    colours = [c for c in found if c not in ("dark",)]
    if use_lib:  # "poison cloud", "black hole", "golden ..." name the effect's own colours: keep its design
        colours = [c for c in colours if c not in catalog.effect_words(entry)]
    if colours:
        palette = palette_from(COLORS[colours[0]], COLORS[colours[1]] if len(colours) > 1 else None, dark)
    elif dark and archetype != "dark" and not (use_lib and catalog.effect_words(entry) & {"dark", "void", "shadow"}):
        palette = palette_from("#8A2BFF", "#FF2F9E", True)
    elif use_lib:
        palette = None  # keep the library effect's own designed colours...
        own = catalog.effect_words(entry)
        hits = []
        for el in ELEMENTS:
            at = [m.start() for w in el["words"] for m in [re.search(r"(?<![a-z])" + w + r"(?![a-z])", text)] if m]
            if at:
                hits.append((min(at), el))
        for _, el in sorted(hits, key=lambda h: h[0]):
            if not own & set(el["words"] + el["native"]):  # ...unless it is asked for in another element
                palette = palette_from(el["colors"][0], el["colors"][1], dark)
                break
    else:
        core, primary, secondary, deep = THEMES[archetype]
        palette = {"core": core, "primary": primary, "secondary": secondary, "deep": deep}

    scale = 1.0
    for w, s in (("tiny", 0.6), ("small", 0.75), ("little", 0.8), ("big", 1.35), ("large", 1.35),
                 ("huge", 1.6), ("massive", 1.8), ("giant", 1.8), ("ultimate", 1.7), ("epic", 1.5)):
        if re.search(r"\b" + w + r"\b", text):
            scale = s
    speed = 1.0
    for w, s in (("fast", 1.3), ("quick", 1.25), ("rapid", 1.3), ("snappy", 1.2), ("slow", 0.75),
                 ("slow-mo", 0.6), ("heavy", 0.85)):
        if re.search(r"\b" + re.escape(w) + r"\b", text):
            speed = s
    base, _, desc = ARCHETYPES[archetype]
    if use_lib:
        base, desc = entry["id"], entry["title"].lower() + (" loop" if entry["ambient"] else "")
    parts = [{"base": base, "t": 0.0, "at": [0, 0, 0], "scale": 1.0}]
    if archetype in ("slash", "projectile", "beam") and re.search(r"\b(and|then|into|with|that)\b.*\b(explo|boom|blast|impact|slam)", text):
        follow = "explosion" if re.search(r"explo|boom|blast", text) else "impact"
        parts.append({"base": follow, "t": 0.25 if archetype == "slash" else 0.4, "at": [0, 0, -6], "scale": 0.9})
    return {
        "type": "vfx",
        "version": 1,
        "name": name or _name_from(prompt, archetype),
        "base": base,
        "archetype": archetype,
        "description": desc,
        "palette": palette,
        "scale": scale,
        "speed": speed,
        "intensity": 1.0,
        "roll": -25.0 if base == "slash" else 0.0,
        "yaw": 0.0,
        "parts": parts,
        "prompt": prompt,
        "analysis": {"confidence": 1.0 if (any(scores.values()) or use_lib) else 0.3, "scores": scores,
                     "library": {"id": entry["id"], "score": lib_score} if use_lib else None},
    }


def _name_from(prompt, archetype):
    words = re.findall(r"[A-Za-z]+", prompt or "")
    words = [w.capitalize() for w in words if w.lower() not in ("a", "an", "the", "with", "and", "of", "that", "make",
                                                                   "me", "create", "vfx", "effect", "please")]
    name = "".join(words[:4]) or archetype.capitalize()
    return name[:40]
