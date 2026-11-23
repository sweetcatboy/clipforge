# Changelog

## 1.2.0

**New**

- **Animations from words**: a library of 40+ hand-keyed moves (jab, cross, hook, uppercut, front and roundhouse
  kicks, sword slash, thrust, overhead slam, spin attack, spell cast, power up, energy beam, throw, ground pound,
  block, idle, fighting stance, walk, run, sprint, jump, backflip, front flip, dash, dodge roll, hit reaction,
  knockdown, dizzy, and emotes: wave, cheer, dance, clap, bow, point, salute, shrug, flex, laugh, victory pose, sad)
  plus punch, sword and kick combos. "jab then cross then uppercut" chains moves; speed, power, side and loop words
  are read. Baked onto any R15 or R6 rig with a Hit marker on contact frames.
- **Make anything from a message**: words go to a router that decides what to make: an animation, an effect, both
  linked as an ability ("fire punch", "kamehameha"), a generated piece, a model or a cutscene. New job kind `auto`
  (the default for words), `POST /api/preview` (what words would make, without a job), MCP tools `clipforge_make`
  and `clipforge_animation_from_prompt`, Discord `!make` and mentions, `!anim` with words, `/clipforge:make`, and
  an Auto choice in the plugin's Create tab and on the server page.
- **Hit-stop** on ability hits (0.03 + 0.045 x strength seconds) and a rotation-led trauma camera shake.
- **VFX**: hits get a real hot frame (a two-layer impact stamp with a solid core that reads in daylight), layered
  shock sheets flat to the strike, smoke puffs and a dim linger: punch, critical, hit spark, uppercut, shockwave,
  crater slam, thrust, parry, landing and dash.
- **Cutscenes**: depth of field that follows the subject, sized from the shot; mood grades (boss, victory, defeat,
  reveal, cold, flashback); handheld camera drift; crash zooms (`zoom` event); letterbox sized for 2.39:1 on the
  actual screen; a new title card (band wipe, the name lands with a sheen, a flash and a small shake, the epithet
  follows); in games the other UI, core UI and mouse icon hide while it plays, the camera blends back to gameplay,
  and a death, respawn or overrun ends it. Templates use longer lenses (boss intro adds a close-up insert).
- **Models**: stylised proportions (a 4-stud one-handed sword, 1:8 blade), edge bevels, fullers, grip wraps, gems,
  a swing trail on every weapon, and a light and sparkles on glowing ones.

**Fixed**

- Held weapons: attaching a model to a rig left the blade behind where the model was built.
- Text animation holds no longer snap back to the stance at the end of a contact hold.
- Cutscene events: one failing event no longer stalls (and re-fires) the rest.

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
