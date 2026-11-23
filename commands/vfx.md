---
description: Make a professional Roblox VFX from a description or a clip (e.g. /clipforge:vfx huge purple lightning slash)
argument-hint: <description | link or video file> [slash|impact|explosion|aura|beam|lightning|projectile|fire|ice|dark|holy]
---

Use the `clipforge` skill (ClipForge plugin) to make a VFX from: $ARGUMENTS

- **If there is a link or file path:** make a `kind = "vfx"` job from the clip. A type word becomes `options.style`;
  the other words are a steering `prompt`. Use the `clipforge_from_video` MCP tool or REST.
- **Otherwise:** the whole text is a description. Use `clipforge_vfx_from_prompt` (or REST
  `{ "prompt": ..., "kind": "vfx" }`). Size words (small, big, huge) and speed words (fast, slow) are understood.
  "... that explodes" and "... into a slam" make a combined two-part effect.

Run the section 0 ready check first. Report as in section 4:

- the effect name and its archetype;
- the palette;
- for clips, the contact-sheet description and confidence;
- where it is in Studio, and the one line that plays it in a game:
  `require(game.ReplicatedStorage.ClipForge.FX).play("<Name>", cframe)`.

Mention that the plugin's Library tab can recolour, resize and re-preview it.
