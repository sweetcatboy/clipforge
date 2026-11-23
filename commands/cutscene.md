---
description: Make a Roblox cutscene from a description or by copying a clip's camera work (e.g. /clipforge:cutscene boss intro "You dare challenge me?")
argument-hint: <description with "quoted lines"> | <link or video file> [who=<actor>] [title=<text>]
---

Use the `clipforge` skill (ClipForge plugin) to make a cutscene from: $ARGUMENTS

- **Words only:** a template is picked from the words (boss intro, victory, dramatic reveal, ability showcase, map
  flyover, dialogue, defeat). Text in quotes becomes dialogue lines; an effect named in the words ("with a
  shockwave", "confetti") fires on the beat.
- **A link or file:** the clip's cuts, camera moves (push in, pull out, orbit, tilt, locked off), shot sizes (close,
  medium, full, wide), shake, flashes and fades are copied onto the user's character, on the clip's timing. Quoted
  lines in the rest of the text still become dialogue. Pass `start`/`end` for part of a clip. Tracking takes
  about as long as the clip.
- `who=<Name>` sets the actor the shots film (default `Target`); `title=<text>` sets the title card.

Make a `kind = "cutscene"` job: the `clipforge_make_cutscene` MCP tool, or REST
`{ "kind": "cutscene", "prompt": ..., "source": ..., "options": { "who": ..., "title": ... } }`.

Run the section 0 ready check first. Report:

- the template (or for a clip: the shot list with moves and sizes, and how many flashes, shakes and fades);
- the name and where it is: `ReplicatedStorage.ClipForge.Cutscenes.<Name>`;
- how to play it in a LocalScript:
  `require(game.ReplicatedStorage.ClipForge.Cutscene).play("<Name>", { actors = { Target = workspace.Boss } })`;
- that it opens in the plugin's **Scenes** tab, where the user selects the character, presses **Use selection** and
  **Preview**, and can retime shots or add lines, effects, shake, titles and fades.
