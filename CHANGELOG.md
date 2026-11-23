# Changelog

## 1.1.0

**New**

- **100-effect library** (was 11 base effects): combat (spin slash, claw strike, punch barrage, knockback, blood
  splatter, stun stars, muzzle flash, bullet impact...), elements (earthquake, earth spikes, lava burst, ice
  shatter, frost nova, chain lightning, steam, acid...), magic (smoke bomb, curse, life drain, arcane bolt, shield
  break, mana burst, time stop, star fall...), movement (super jump, launch pad, slide dust, jet burst...), game feel
  (coin burst, egg hatch, loot beam, quest complete, rebirth, XP gain, boss spawn...) and ambient loops (rain, snow,
  falling leaves, cherry blossoms, bubbles, spirit wisps, light rays...). Search, categories and favourites in the
  plugin's VFX tab.
- **VFX generator** for showcase pieces: glowing or wireframe cubes, crystals and orbs with orbit rings, wings,
  halos, hearts, rune circles, light shafts, lightning arcs, nebula, stars, floating squares, petals, leaves,
  chromatic fringes; plus impact and black-hole modes. Reroll for variations.
- **Cutscenes**: templates (boss intro, victory, dramatic reveal, ability showcase, map flyover, dialogue, defeat),
  cutscenes from a description with dialogue, or from a clip's own editing and camera work (cuts, push-ins,
  orbits, tilts, shot sizes, shake, flashes, fades). Letterbox, typewriter subtitles, titles, effects, slow motion.
  Shots scale with the filmed character's size.
- **Models**: 17 weapon and prop types in 6 styles with a glow colour; attach to a rig, make a Tool or save.
- **Abilities**: an animation and its effects in sync; clips with both get one automatically, firing the effect
  on the detected hit.
- **Customisable look**: Studio, Dark, Midnight and Light themes, any accent colour, text size and density.
- **Bots**: new job kinds `generate`, `cutscene` (prompt or clip) and `model`; `GET /api/catalog`; MCP tools
  `clipforge_generate_vfx`, `clipforge_make_cutscene`, `clipforge_make_model`; CLI `--kind generate|cutscene|model`;
  Discord `!gen`, `!cutscene`, `!model`. Claude commands `/clipforge:generate`, `/clipforge:cutscene`,
  `/clipforge:model`.
- Prompts now match the whole library and recolour by element ("ice slam", "fire tornado"), the same way in the
  plugin and on the server.

**Fixed**

- Long clips (about 10 s and up) could never be built in Studio: their saved motion data went over Roblox's
  200,000-character script limit, and the plugin retried forever. Motion data is now split into parts, a failed
  build is reported once (with **Build here** to retry), and the server pauses a job after 3 failed builds so older
  plugin versions stop retrying.
- Building several models in a row stacked them on top of each other; they now line up side by side.
- Cutscene dialogue no longer resizes while it types; titles sit in the lower third.

## 1.0.0

First release: clips from YouTube, TikTok, Instagram, X and more into Roblox animations (pose tracking,
retargeting to R15/R6) and VFX (palette, timing and motion read into 11 professional base recipes); Studio plugin,
local bot server with REST API, MCP tools, CLI, Discord bot example and a Claude Code plugin.
