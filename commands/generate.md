---
description: Generate a showcase-grade composed VFX from a description (e.g. /clipforge:generate golden glowing cube with light wings)
argument-hint: <description> [showcase|impact|vortex] [chromatic] [seed N]
---

Use the `clipforge` skill (ClipForge plugin) to generate a VFX from: $ARGUMENTS

This is the generator (section 2b of the skill), not the effect library: it composes a hero piece with frames,
energy and atmosphere, like a portfolio showcase.

- Strip the option words from the text: `showcase`, `impact` or `vortex` force the `mode`; `chromatic` (or
  "rainbow fringes") forces `chromatic: true`, "no chromatic" forces `false`; `seed N` / "another version" picks a
  new `seed` (use the previous seed + 1 when the user asks for another take of the same idea).
- Make a `kind = "generate"` job with the rest as `prompt`: the `clipforge_generate_vfx` MCP tool, or REST
  `{ "kind": "generate", "prompt": ..., "options": { "mode": ..., "seed": ..., "chromatic": ... } }`.
- It returns in about a second; Studio builds it when Bot Link is on.

Run the section 0 ready check first. Report:

- what it is, from the job message (mode, hero, frames, energy, atmosphere, palette, chromatic);
- the effect name and where it is: `ReplicatedStorage.ClipForge.Effects.<Name>`, played in a game with
  `require(game.ReplicatedStorage.ClipForge.FX).play("<Name>", cframe)`;
- that the plugin's VFX tab has the same generator (Generate / Reroll) for quick variations.

If the words describe an ordinary attack or element effect ("ice slam", "heal") rather than a showcase piece,
suggest `/clipforge:vfx`, which uses the 100-effect library.
