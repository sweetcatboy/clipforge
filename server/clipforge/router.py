"""Free-form message -> what to make.

Bots forward whatever people type ("fire punch", "make me a backflip", "huge purple slash effect", "glowing katana",
"boss intro cutscene"). This reads the message and plans the outputs of one job: an animation, an effect, both
(linked as an ability: the effect fires on the animation's Hit marker), a generated showcase effect, a model or a
cutscene. The same rules decide what the plugin's Create tab does with typed text.
"""
from __future__ import annotations

import re

from . import catalog, text_motion

ANIM_WORDS = ("animation", "animations", "anim", "anims", "animate", "emote", "emotes", "moveset", "motion",
              "keyframe", "keyframes", "pose")
VFX_WORDS = ("vfx", "effect", "effects", "fx", "particle", "particles", "visual", "visuals", "aura", "glow")
MODEL_WORDS = ("model", "weapon", "prop", "item", "mesh", "tool", "build me", "make me a sword")
CUTSCENE_WORDS = ("cutscene", "cut scene", "cinematic", "cinematics", "intro scene", "camera shot", "flyover",
                  "boss intro", "boss entrance", "dramatic reveal", "map flyover", "dialogue scene", "establishing shot",
                  "victory scene", "defeat scene", "death scene", "story scene")
# with a quoted line ("boss intro \"You dare?\""), these words mean a scene with dialogue
SCENE_WORDS = ("intro", "boss", "victory", "reveal", "dialogue", "conversation", "defeat", "scene", "npc", "says", "talk")
GENERATE_WORDS = ("showcase", "cube", "wireframe", "orb", "wings", "halo", "nebula", "galaxy", "black hole",
                  "tesseract", "artifact", "generate", "generated")
INTRINSIC_FX = ("beam", "charge", "cast")  # moves that are mostly their effect
ELEMENT_WORDS = ("fire", "flame", "flaming", "ice", "frost", "frozen", "lightning", "electric", "thunder", "holy",
                 "divine", "dark", "shadow", "void", "water", "wind", "poison", "toxic", "lava", "magma", "blood",
                 "energy", "plasma", "nature", "light")


def _has(text, w):
    return re.search(r"(?<![a-z])" + re.escape(w) + r"(?![a-z])", text) is not None


def _any(text, words):
    return any(_has(text, w) for w in words)


def plan(message: str, kind: str = "auto") -> dict:
    """{"animation": bool, "vfx": bool, "generate": bool, "model": bool, "cutscene": bool, "move": id|None,
    "effect": library id|None, "reason": str}."""
    text = " " + (message or "").lower() + " "
    move, mscore = text_motion.match_move(message)
    effect, vscore = catalog.match_effect(message)
    colours = _any(text, ELEMENT_WORDS) or _any(text, catalog.MODEL_COLORS)
    out = {"animation": False, "vfx": False, "generate": False, "model": False, "cutscene": False,
           "move": move if mscore >= 1 else None, "effect": effect["id"] if effect and vscore >= 2 else None, "reason": ""}

    if kind in ("animation", "vfx", "both"):
        out["animation"] = kind in ("animation", "both")
        out["vfx"] = kind in ("vfx", "both")
        out["reason"] = f"asked for {kind}"
        return out
    if kind in ("generate", "model", "cutscene"):
        out[kind] = True
        out["reason"] = f"asked for {kind}"
        return out

    wants_anim, wants_vfx = _any(text, ANIM_WORDS), _any(text, VFX_WORDS)
    quoted = re.search(r'["“][^"”]{2,}["”]', message or "") is not None
    if (_any(text, CUTSCENE_WORDS) or (quoted and _any(text, SCENE_WORDS))) and not wants_anim:
        out["cutscene"], out["reason"] = True, "cutscene words"
        return out
    model = catalog.model_from_prompt(message)
    model_named = any(_has(text, w) for t in catalog.catalog()["models"] for w in re.findall(r"[a-z]+", t["tags"])
                      if len(w) > 3)
    action_words = mscore >= 2 and not (model_named and mscore < 4)
    if (_any(text, MODEL_WORDS) or (model_named and not action_words and not wants_vfx)) and not wants_anim:
        out["model"], out["reason"] = True, f"a {model['type']} model"
        return out
    if _any(text, GENERATE_WORDS) and not wants_anim and not (effect and vscore >= 8):
        out["generate"], out["reason"] = True, "a showcase piece"
        return out

    effect_named = bool(effect) and vscore >= 8      # an effect's whole title ("chain lightning", "coin burst")
    move_named = mscore >= 8                          # a move's whole title ("backflip", "uppercut")
    joined = re.search(r"(?<![a-z])(with|plus|and|while|\+)(?![a-z])", text) is not None
    if wants_anim:
        out["animation"] = True
    elif mscore >= 2 and not wants_vfx:
        # "coin burst" / "chain lightning" are effects that merely share a move's tag; "punch with an explosion" is both
        out["animation"] = joined if (effect_named and not move_named) else True
    if wants_vfx or (out["animation"] and colours):
        out["vfx"] = True
    elif out["animation"] and effect and vscore >= 2.5 and joined:  # "cheer with confetti", "punch with an explosion"
        out["vfx"] = True
    elif out["animation"] and not wants_anim and out["move"] in INTRINSIC_FX:  # a kamehameha comes with its beam
        out["vfx"] = True
    if not out["animation"] and not out["vfx"]:
        if vscore >= 2:
            out["vfx"] = True
        elif mscore >= 1:
            out["animation"] = True
        else:
            out["generate"] = True
    if out["animation"] and not out["move"]:
        out["animation"] = False
        out["vfx"] = True
    bits = [k for k in ("animation", "vfx") if out[k]]
    out["reason"] = " + ".join(bits) or "generate"
    return out


def vfx_prompt_for(message: str, move: str | None) -> str:
    """The effect prompt for a message that also makes an animation: an effect the message names wins; otherwise
    the move's own effect, in the colours or element the message asks for."""
    effect, score = catalog.match_effect(message)
    if (effect and score >= 8) or not move:
        return message
    fx, _ = text_motion.MOVE_FX.get(move, ("hitspark", "Front"))
    title = next((e["title"] for e in catalog.effects() if e["id"] == fx), fx)
    text = " " + (message or "").lower() + " "
    extra = [w for w in list(ELEMENT_WORDS) + list(catalog.MODEL_COLORS) if _has(text, w)]
    size = [w for w in ("tiny", "small", "big", "huge", "massive", "giant") if _has(text, w)]
    return " ".join(size + extra + [title.lower()])
