---
description: Make a Roblox weapon or prop model from a description (e.g. /clipforge:model glowing purple katana)
argument-hint: <description> [steel|dark|gold|crystal|energy|wood] [glow #RRGGBB]
---

Use the `clipforge` skill (ClipForge plugin) to make a model from: $ARGUMENTS

Types: sword, katana, greatsword, dagger, axe, spear, staff, wand, scythe, hammer, shield, magic orb, crystal
cluster, rock, meteor, portal, rune totem. Styles: steel, dark, gold, crystal, energy, wood. A colour word or a hex
code is the glow; size words (small, big, huge) scale it.

Make a `kind = "model"` job: the `clipforge_make_model` MCP tool, or REST
`{ "kind": "model", "prompt": ..., "options": { "style": ..., "glow": ..., "scale": ... } }`. It returns in about a
second; Studio builds it in the workspace where the camera looks when Bot Link is on.

Run the section 0 ready check first. Report:

- what was made (style, type, glow) and its name;
- that in the plugin's **Models** tab the user can **Attach to rig** (welded to the right hand, so it follows
  animation previews), **Make Tool** (goes in StarterPack, players spawn holding it) or **Save** it to
  `ReplicatedStorage.ClipForge.Models`;
- it is plain parts, so it can be recoloured or edited freely.

If it should come with an effect (a flaming sword), suggest `/clipforge:vfx` for the effect and the Animations tab's
Ability card to fire it from an attack animation.
