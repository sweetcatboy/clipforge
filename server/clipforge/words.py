"""Word forms people type -> the words the move and effect libraries are tagged with.

"exploding" finds the explosion, "punching" the punch, "freezing" ice. The base word is added next to the original
(nothing is removed), so titles such as "Falling Leaves" still match as written. The plugin's Library.luau keeps the
same table for its offline matching.
"""
from __future__ import annotations

import re

FORMS = {
    # effects
    "explode": "explosion", "explodes": "explosion", "exploding": "explosion", "exploded": "explosion",
    "explosive": "explosion", "kaboom": "explosion", "blow up": "explosion", "blows up": "explosion",
    "nuke": "explosion", "nuked": "explosion", "fireworks": "firework", "snowing": "snow", "raining": "rain",
    "saiyan": "aura",
    "turns into": "transform", "turn into": "transform", "turning into": "transform", "turned into": "transform",
    "transforms": "transform", "transforming": "transform", "morph": "transform", "morphs": "transform",
    "becomes": "transform", "become": "transform",
    "freeze": "ice", "freezes": "ice", "freezing": "ice", "icy": "ice",
    "burn": "fire", "burns": "fire", "burning": "fire", "blazing": "fire", "fiery": "fire",
    "zap": "lightning", "zaps": "lightning", "zapping": "lightning", "electrocute": "lightning",
    "heals": "heal", "healing": "heal", "healed": "heal",
    "teleports": "teleport", "teleporting": "teleport",
    "shielding": "shield", "shields": "shield",
    "summons": "summon", "summoning": "summon",
    "slashing": "slash", "slashes": "slash", "slashed": "slash", "slice": "slash", "slicing": "slash",
    "smashing": "smash", "smashes": "smash", "slamming": "slam", "slams": "slam",
    "stabbing": "stab", "stabs": "stab", "stabbed": "stab",
    # moves
    "punching": "punch", "punches": "punch", "punched": "punch",
    "kicking": "kick", "kicks": "kick", "kicked": "kick",
    "jumping": "jump", "jumps": "jump", "leaping": "leap",
    "flipping": "flip", "flips": "flip",
    "dancing": "dance", "dances": "dance",
    "running": "run", "runs": "run", "jog": "run", "jogs": "run", "jogging": "run",
    "walking": "walk", "walks": "walk",
    "sprinting": "sprint", "dashing": "dash", "dashes": "dash",
    "rolling": "roll", "rolls": "roll",
    "waving": "wave",
    "cheering": "cheer", "celebrating": "celebrate",
    "clapping": "clap", "claps": "clap",
    "bowing": "bow", "pointing": "point", "saluting": "salute", "shrugging": "shrug", "flexing": "flex",
    "laughing": "laugh", "crying": "cry",
    "blocking": "block", "parrying": "parry",
    "throwing": "throw", "throws": "throw",
    "casting": "cast", "casts": "cast",
    "charging": "charge",
    "spinning": "spin", "spins": "spin",
    "dodging": "dodge", "dodges": "dodge",
    "dying": "die", "dies": "die",
}


def _has(text: str, w: str) -> bool:
    return re.search(r"(?<![a-z])" + re.escape(w) + r"(?![a-z])", text) is not None


def normalize(text: str | None) -> str:
    """Lower-case text with the base form of every recognised word form appended."""
    t = (text or "").lower()
    extra = [base for form, base in FORMS.items() if _has(t, form)]
    return t + (" " + " ".join(dict.fromkeys(extra)) if extra else "")
