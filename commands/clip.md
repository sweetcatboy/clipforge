---
description: Turn a YouTube / TikTok / Instagram / X clip into a Roblox animation and VFX (e.g. /clipforge:clip https://youtu.be/... 3-9)
argument-hint: <link or video file> [animation|vfx|both] [start-end] [name] [loop] [mirror]
---

Use the `clipforge` skill (ClipForge plugin) to make Roblox content from this clip: $ARGUMENTS

1. Run the skill's section 0 ready check (set up, server up, Studio plugin installed). Fix what is missing first.
2. Read the arguments:
   - the link or file path is the `source`;
   - `animation`, `vfx` or `both` is the `kind` (default `both`);
   - `A-B` or `A to B` (seconds or m:ss) becomes `options.start`/`end`;
   - a PascalCase word is the `name`;
   - `loop`, `mirror`, `travel` (rootMotion full), `locked` (rootMotion none) and `face-forward` (lockFacing) are
     options;
   - any other words are a steering `prompt` for the VFX ("make it purple").
3. Create the job with the `clipforge_from_video` MCP tool (wait for it), or with the REST call in section 2. Tell the
   user it is working: body tracking takes about as long as the clip.
4. Report as in section 4: what was made, the names and where they land in Studio, the VFX archetype, confidence and
   palette (look at the contact sheet), and the animation's length, keys and detection quality. If `delivered` is
   false, remind them to turn on Bot Link in the ClipForge widget.
