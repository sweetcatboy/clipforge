---
description: Make a professional Roblox VFX from a description or a clip (e.g. /clipforge:vfx huge purple lightning slash)
argument-hint: <description | link or video file> [slash|impact|explosion|aura|beam|lightning|projectile|fire|ice|dark|holy]
---

Use the `clipforge` skill (ClipForge plugin) to make a VFX from: $ARGUMENTS

- **If there is a link or file path:** make a `kind = "vfx"` job from the clip. A type word becomes `options.style`;
  the other words are a steering `prompt`. Use the `clipforge_from_video` MCP tool or REST.
- **Otherwise:** the whole text is a description. Use `clipforge_vfx_from_prompt` (or REST
  `{ "prompt": ..., "kind": "vfx" }`). It picks from the 100-effect library (combat, elements, magic, movement, game
  feel, ambient loops) and recolours it from colour or element words. Size words (small, big, huge) and speed words
  (fast, slow) are understood. "... that explodes" and "... into a slam" make a combined two-part effect.
- If the words describe a showcase piece (a glowing cube with wings, a wireframe cube with orbit rings, a black hole
  with floating rocks), use `/clipforge:generate` instead.

Run the section 0 ready check first. Report as in section 4:

- the effect name and its archetype;
- the palette;
- for clips, the contact-sheet description and confidence;
- where it is in Studio, and the one line that plays it in a game:
  `require(game.ReplicatedStorage.ClipForge.FX).play("<Name>", cframe)`.

Mention that the plugin's VFX tab can recolour, resize and re-preview it.
