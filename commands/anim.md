---
description: Make a Roblox animation (R15/R6) from the body motion in a video clip (e.g. /clipforge:anim https://www.tiktok.com/... loop)
argument-hint: <link or video file> [start-end] [name] [loop] [mirror] [travel|inplace|locked] [face-forward] [crisp|silky]
---

Use the `clipforge` skill (ClipForge plugin) to make an animation only (`kind = "animation"`) from: $ARGUMENTS

Run the section 0 ready check, then map the words to options with the section 2 table:

- `A-B` becomes start/end;
- `loop` and `mirror`;
- `travel` = rootMotion full, `inplace` (the default), `locked` = rootMotion none;
- `face-forward` = lockFacing;
- `crisp` = smoothing 0.25, `silky` = smoothing 0.8.

Create the job (the `clipforge_from_video` MCP tool or REST), wait, and report as in section 4: name, duration, keys,
detection quality, where it is in Studio, and how to publish it (Animations tab > Publish) and play it in a game.
If no person was detected, explain what clip would work (section 5).
