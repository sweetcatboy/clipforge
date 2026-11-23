---
description: Make a Roblox animation (R15/R6) from a video clip's body motion or from words (e.g. /clipforge:anim uppercut, /clipforge:anim https://www.tiktok.com/... loop)
argument-hint: <link or video file | move words> [start-end] [name] [loop] [mirror] [travel|inplace|locked] [face-forward] [crisp|silky] [with effect]
---

Use the `clipforge` skill (ClipForge plugin) to make an animation only (`kind = "animation"`) from: $ARGUMENTS

**No link or file, just words** ("uppercut", "fast sword slash", "jab then cross then hook", "looping idle"): use the
`clipforge_animation_from_prompt` MCP tool (or REST `{ "prompt": ..., "kind": "animation" }`). "with effect" or
"with VFX" sets `effect: true` (REST `kind = "both"`): the move's effect fires on its Hit frame as an ability.
Report the move(s), duration and the Hit marker, then stop here.

**A link or file:** run the section 0 ready check, then map the words to options with the section 2 table:

- `A-B` becomes start/end;
- `loop` and `mirror`;
- `travel` = rootMotion full, `inplace` (the default), `locked` = rootMotion none;
- `face-forward` = lockFacing;
- `crisp` = smoothing 0.25, `silky` = smoothing 0.8.

Create the job (the `clipforge_from_video` MCP tool or REST), wait, and report as in section 4: name, duration, keys,
detection quality, where it is in Studio, and how to publish it (Animations tab > Publish) and play it in a game.
If no person was detected, explain what clip would work (section 5).
