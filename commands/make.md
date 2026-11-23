---
description: Make whatever the words ask for in Roblox - an animation, an effect, both as an ability, a model or a cutscene (e.g. /clipforge:make fire punch)
argument-hint: <what you want, in plain words> [fast|slow] [left] [loop]
---

Use the `clipforge` skill (ClipForge plugin) to make what this asks for: $ARGUMENTS

Run the section 0 ready check. Then send the words as they are, with `kind = "auto"`: the `clipforge_make` MCP tool
(`message`), or REST `{ "prompt": ..., "kind": "auto" }`. If there is a link or file path, use
`clipforge_from_video` with `kind = "both"` instead.

- The server reads the words: "fire punch" = a punch animation + a fire impact linked as an ability (the effect
  fires on the Hit frame with hit-stop and shake); "backflip" = an animation; "kamehameha" = the beam move + its
  beam; "chain lightning" = an effect; "glowing katana" = a model; "boss intro" = a cutscene.
- When it is unclear what the user wants, preview first (`preview: true`, or `POST /api/preview`) and say what it
  would make.
- Speed words, left/mirror and loop are read from the words; pass `speed`, `mirror` or `loop` only when the user
  says them separately.

Report as in section 4: what was made (the job `message`), the names, where they are in Studio, and for an ability
the line that plays it in a game.
