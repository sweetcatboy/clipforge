# ClipForge: video to Roblox animation & VFX

ClipForge is a Roblox Studio plugin and a local "bot server". It turns clips from YouTube (and Shorts), TikTok,
Instagram Reels, X, Reddit, Twitch clips and more, or a video file, into:

- **Animations**: the person's body motion becomes a `KeyframeSequence` for your rig (R15 or R6, any
  proportions, classic `Motor6D` or the newer `AnimationConstraint` joints).
- **VFX**: the clip's effect (a slash, a slam, an explosion, an aura...) is read for its palette, timing, motion and
  shape. ClipForge then builds a layered effect in that style from studied professional recipes.
- **Cutscenes**: copy a clip's editing and camera work (cuts, push-ins, orbits, shake, flashes, fades) onto your
  own character, or make one from a description with dialogue, titles, letterbox and effects.

It also works without a video. Type what you want in plain words ("fire punch", "backflip", "kamehameha",
"glowing katana", "boss intro") and ClipForge works out what to make:

- **animations from words**: a library of hand-keyed moves (punches, kicks, sword slashes, thrusts, overhead slams,
  spins, casts, beams, jumps, flips, rolls, dashes, runs, reactions, emotes and combos) with anticipation, snappy
  strikes, held contact frames, follow-through and overlap, baked onto any R15 or R6 rig with a Hit marker on every
  contact. "jab then cross then uppercut" chains moves; fast, slow, heavy and left are understood;
- a **library of 100 effects** (combat, elements, magic, movement, game feel, ambient loops), recoloured and sized
  from plain words ("ice slam", "huge purple lightning slash", "coin burst");
- a **VFX generator** for showcase pieces: a glowing cube, wireframe cube, crystal or orb with orbit rings, wings,
  halos, light shafts, lightning, nebula, stars, floating squares, petals or leaves, chromatic fringes;
- **models**: swords, katanas, axes, spears, staffs, scythes, hammers, shields, orbs, crystals, meteors, portals and
  totems in steel, dark, gold, crystal, energy or wood styles, with a glow colour, ready to hold or turn into Tools;
- **abilities**: an animation and its effects in sync: the effect fires on the hit frame, with hit-stop and camera
  shake ("fire punch" makes all three at once). Video animations get Hit markers where a hand or foot lands;
- **Try in game**: one click puts a tool in StarterPack that plays an animation and its effects when clicked, holding
  your weapon. Press Play to see exactly how it looks in the game;
- a customisable plugin look: Studio, Dark, Midnight or Light theme, your accent colour, text size and density.

Bots can do all of this too. Discord bots, scripts and automations use the REST API, and AI agents (Claude,
Cursor...) use the MCP server. Whatever a bot makes is built in your open Studio place.

```
 bots / AI agents / you ──► ClipForge bot server (local) ──► Studio plugin builds it in your place
   (REST, MCP, CLI)          download → pose tracking →        KeyframeSequences + effect configs,
                             retarget / read the VFX            preview, publish, in-game runtime
```

## Use it from Claude Code (plugin)

This repo is a Claude Code plugin with its own marketplace. Install it with:

```
/plugin marketplace add sweetcatboy/clipforge
/plugin install clipforge@clipforge
/clipforge:setup
```

| Command | What it does |
|---|---|
| `/clipforge:setup [check]` | Install everything (Python env, pose model, Studio plugin, bot server), or only report what is missing |
| `/clipforge:make <anything>` | Whatever the words ask for: "fire punch", "backflip", "glowing katana", "boss intro" |
| `/clipforge:clip <link> [animation\|vfx\|both] [3-9] [Name]` | Clip to animation and/or VFX, built in Studio |
| `/clipforge:anim <link or moves> [loop] [mirror] [travel]` | Animation only, from a clip or from words ("jab then cross") |
| `/clipforge:vfx <description or link>` | VFX from the 100-effect library ("huge purple lightning slash", "coin burst") or a clip |
| `/clipforge:generate <description>` | Showcase VFX from the generator ("golden glowing cube with light wings") |
| `/clipforge:cutscene <description or link>` | Cutscene from a description (`boss intro "You dare?"`) or a clip's camera work |
| `/clipforge:model <description>` | Weapon or prop model ("glowing purple katana") |
| `/clipforge:server [start\|stop\|status\|public]` | Manage the bot server |
| `/clipforge:jobs [n \| id]` | Recent jobs and whether Studio built them |
| `/clipforge:studio [install\|build]` | Install or update the Studio plugin, or build the `.rbxmx` to share |

The plugin also brings the `clipforge` skill and the ClipForge MCP tools, so Claude uses them by itself when you
ask for a Roblox animation or VFX from a video. Publishing your own copy: [docs/PUBLISHING.md](docs/PUBLISHING.md).

## Install by hand (Windows)

1. **Setup (once):** in this folder run
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\setup.ps1
   ```
   This installs everything into `%USERPROFILE%\.clipforge`:
   - a Python 3.12 environment (a short path, which MediaPipe needs);
   - MediaPipe, OpenCV and yt-dlp;
   - the pose model;
   - and, later, the jobs and the bot token.

   You also need `ffmpeg` (`winget install Gyan.FFmpeg`).
2. **Plugin:** it is already installed if you see **ClipForge** in Studio's Plugins tab. To (re)install:
   ```powershell
   & "$env:USERPROFILE\.clipforge\venv\Scripts\python.exe" scripts\build_plugin.py --install
   ```
   (or copy `dist\ClipForge.rbxmx` into `%LOCALAPPDATA%\Roblox\Plugins`).
3. **Bot server:** keep it running while you work:
   ```powershell
   .\start-server.ps1
   ```
   The first time the plugin connects, Studio asks whether ClipForge may access `127.0.0.1`: allow it.

## Using the plugin

| Tab | What it does |
|---|---|
| **Create** | Paste a link (or a file path) or type what you want ("fire punch", "backflip", "heavy sword slash"), pick Auto / Animation / VFX / Both, optionally a start/end time, press **Generate**. Animation options: In place / Travels / Locked root, Crisp / Smooth / Silky filtering, loop, mirror, face forward. VFX options: Auto or force a type, plus a steering text ("make it purple"). It builds itself when ready. |
| **VFX** | **Generate a VFX** from a description (Auto / Showcase / Impact / Vortex, chromatic fringes, Reroll for variations). The **effect library**: 100 effects to search, filter by category and star as favourites. Describe one ("huge purple lightning slash"; works offline), recolour it with presets, hex codes or your saved palettes, set size, speed and slash angle, preview it where the camera looks, then **Insert into game**. |
| **Anim** | Every generated animation: **Play** on the preview rig with its linked effects firing on their hits (select any character, or spawn an R15/R6 dummy), **Try in game** (a tool in StarterPack: press Play, equip it, click), **Re-bake** on another rig, **Edit** in the Animation Editor, **Publish** to your account. The **Ability** card syncs an effect to the animation's hit (Front, Ground, a hand, Root or the Weapon) and saves it as an ability. |
| **Scenes** | Cutscenes: pick a template (boss intro, victory, dramatic reveal, ability showcase, map flyover, dialogue, defeat) or describe one, add shots from your camera view, lines, effects, shake, titles and fades, **Preview** and **Save to game**. |
| **Models** | Weapons and props from a description or the type, style and glow pickers. **Attach to rig** (held in the hand during previews), **Make Tool** (players spawn with it), **Try with animation** (a tool that holds the weapon and plays the last animation you played, with its effects, when clicked) or **Save**. |
| **Bots** | Server address and status, **Bot Link** (this Studio window builds what bots send), the job feed (who asked, what was made, where it went, and **Build here** to retry one). |
| **⚙** | Theme (Studio, Dark, Midnight, Light), accent colour, text size and density. Saved between sessions. |

Where things go in your place:

- `ReplicatedStorage.ClipForge`: the runtime (`FX`, `VFXTimeline`, `Recolor`, `Blocks`, `Library`, `Generator`,
  `Cutscene`, `Abilities`, `Recipes`) and `Effects/`, `Cutscenes/`, `Abilities/`, `Models/`: one small, editable
  module (or model) per thing you saved.
- `ServerStorage.ClipForge.Animations`: the KeyframeSequences. `MotionData` keeps the raw motion for re-baking.
- `ServerStorage.RBX_ANIMSAVES`: a copy the Animation Editor can load.

### Play an effect in your game (LocalScript)

```lua
local FX = require(game.ReplicatedStorage.ClipForge.FX)
FX.preload("PurpleSlash")                                   -- once at load
FX.play("PurpleSlash", character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3))
FX.play("GroundSlam", hitPosition, { scale = 1.4, speed = 0.9 })  -- CFrame, Vector3, part, attachment or model
```

Effects are visual, so play them on clients. For a server-side ability, fire a RemoteEvent to all clients with the
effect name and CFrame, then call `FX.play` there. Library effects play by id too (`FX.play("coinburst", pos)`);
looping ones (rain, campfire, loot beam...) run until you call `:stop()` on the handle `FX.play` returns.

### Play a cutscene or an ability (LocalScript)

```lua
local Cutscene = require(game.ReplicatedStorage.ClipForge.Cutscene)
Cutscene.play("BossIntro", { actors = { Target = workspace.Boss } })   -- shots film the "Target" actor

local Abilities = require(game.ReplicatedStorage.ClipForge.Abilities)
Abilities.play("SlashAbility", player.Character)                       -- animation + its effects in sync
-- (or try one without code: Anim > Try in game, then Play)
```

### Use an animation in your game

**Animations > Publish** uploads it (Studio asks first) and gives you an asset id. Then:

```lua
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://<id>"
humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(anim):Play()
```

## For bots

**REST API** (`http://127.0.0.1:7313`; spec at `/openapi.json`; a small dashboard at `/`):

```bash
# a clip -> animation + VFX
curl -X POST http://127.0.0.1:7313/api/jobs -H "Content-Type: application/json" \
     -d '{"source": "https://www.youtube.com/shorts/<id>", "kind": "both", "options": {"start": 2, "end": 9}, "client": "my-bot"}'
# any words: the server reads them (an animation, an effect, both as an ability, a model or a cutscene)
curl -X POST http://127.0.0.1:7313/api/jobs -H "Content-Type: application/json" \
     -d '{"prompt": "fire punch", "client": "my-bot"}'
curl -X POST http://127.0.0.1:7313/api/jobs -H "Content-Type: application/json" \
     -d '{"prompt": "jab then cross then uppercut", "kind": "animation"}'
# what words would make, without making anything
curl -X POST http://127.0.0.1:7313/api/preview -H "Content-Type: application/json" -d '{"prompt": "kamehameha"}'
# generated showcase VFX, a cutscene, a model
curl -X POST http://127.0.0.1:7313/api/jobs -H "Content-Type: application/json" \
     -d '{"kind": "generate", "prompt": "galaxy wireframe cube with orbit rings"}'
curl -X POST http://127.0.0.1:7313/api/jobs -H "Content-Type: application/json" \
     -d '{"kind": "cutscene", "prompt": "boss intro \"You dare challenge me?\"", "options": {"who": "Boss"}}'
curl -X POST http://127.0.0.1:7313/api/jobs -H "Content-Type: application/json" \
     -d '{"kind": "model", "prompt": "glowing purple katana"}'
# wait for it (long-poll up to 300 s)
curl "http://127.0.0.1:7313/api/jobs/<id>?wait=60"
```

| Endpoint | |
|---|---|
| `POST /api/jobs` | `source` (link or file path) and/or `prompt`, `kind` (`auto`, the default for words: the server reads them; `animation`/`vfx`/`both` from a clip or from words; `generate`; `cutscene` from a prompt or a clip; `model`), `name`, `client`, `options` (clips: `start`, `end`, `rootMotion`: `inplace`/`full`/`none`, `smoothing` 0-1, `loop`, `mirror`, `lockFacing`, `speed`, `style`, `scale`; words: `speed`, `loop`, `mirror`; generate: `mode`, `seed`, `chromatic`; cutscene: `who`, `template`, `title`, `effect`; model: `style`, `glow`, `scale`) |
| `POST /api/preview` | the same body; says what the words would make (the plan, the message and the result) without queueing a job |
| `GET /api/jobs/{id}?wait=s` | status, progress, message, summary, `delivered` (built in Studio), `buildError` (Studio could not build it) |
| `GET /api/catalog` | everything Studio can build: the 100 effects, the animation moves, generator options, cutscene templates, model types |
| `GET /api/jobs/{id}/result` | the full animation keys / effect config |
| `GET /api/jobs/{id}/files/sheet.jpg` | contact sheet of what the VFX reader saw, with the palette |
| `GET /api/jobs` · `DELETE /api/jobs/{id}` · `GET /api/presets` · `GET /api/health` | |

Bots on another machine: run `.\start-server.ps1 -Public` and send `Authorization: Bearer <token>`. The token is in
`%USERPROFILE%\.clipforge\data\bot_token.txt`. Local requests need no token. Requests from web pages are refused, so a
website can't drive your server.

**MCP (AI agents):** tools `clipforge_make` (any request in plain words, with a `preview` option),
`clipforge_animation_from_prompt`, `clipforge_from_video`, `clipforge_vfx_from_prompt`, `clipforge_generate_vfx`,
`clipforge_make_cutscene`, `clipforge_make_model`, `clipforge_job_status`, `clipforge_list_jobs`, `clipforge_presets`. If no bot server is running, the MCP server starts one. The Claude Code
plugin registers it for you (`.mcp.json`). To add it by hand to Claude Code:

```powershell
claude mcp add clipforge --env PYTHONPATH="<this folder>\server" -- "$env:USERPROFILE\.clipforge\venv\Scripts\python.exe" -m clipforge mcp
```

JSON clients (Claude Desktop, Cursor): `"command": "<user>\\.clipforge\\venv\\Scripts\\python.exe"`,
`"args": ["-m", "clipforge", "mcp"]`, `"env": {"PYTHONPATH": "<this folder>\\server"}`.

**CLI:** `python -m clipforge make <link> --kind both --start 3 --end 9`,
`python -m clipforge make --prompt "small holy heal"`, or `--kind generate|cutscene|model --prompt "..."`. Run it
from `server\` with the venv's python.

**Discord:** `examples/discord_bot.py` is a ready-made bot with `!make` (any words; mentioning the bot works too),
`!clip`, `!anim` (a link or words), `!vfx`, `!gen`, `!cutscene` and `!model` commands.

## How it makes it look professional

**Animation:** MediaPipe's heavy pose model gives 3D landmarks for every frame. ClipForge then:

- removes jitter with a zero-phase One Euro filter, which keeps fast hits sharp;
- levels out the camera's tilt and makes the clip start facing forward;
- solves each body part's rotation, including twist (from elbow and knee bend planes, hands and feet), with
  temporal continuity;
- calibrates the head and foot landmark bias;
- derives root motion from planted feet, so feet don't slide. *In place* keeps the sway and steps but drops travel;
- keeps the soles on the ground with forward kinematics on **your** rig, so crouches and stances land right;
- blends loops seamlessly, and keeps only the keys that matter with error-driven reduction (about 1° tolerance).

**Animations from words:** every move is keyed the way animators key combat: an anticipation pose, a strike in
2-4 frames, a held contact frame that drifts a few degrees instead of freezing, a follow-through, and joints that
trail their parents (hips, then chest, shoulder, elbow, wrist). Weapon and punch poses are solved for where the
hand lands and where the blade points, so slashes cut through the centre and fists land at the target. Moves are
baked at 30 fps with error-driven key reduction and a Hit marker on each contact frame. Abilities freeze the
attacker for 0.03 + 0.045 x strength seconds on each hit (hit-stop) and shake the camera trauma-style (mostly
rotation, falling off squared).

**VFX:** effects are not traced from the video. The clip is *measured*:

- the glow palette: white core, saturated body, deep tone;
- the rhythm: wind-up, hit, decay, beats;
- the motion signature: bursting out, sucking in, sweeping, rising, travelling, flickering;
- the shape: round or long.

Those numbers pick and fit one of 11 professional base recipes. Each recipe was distilled from roughly 1,200
studied open-source Roblox effects: layered impact frames with ink twins, flipbooks, racing rings, smoke,
embers, scorch marks. ClipForge recolours a recipe without flattening its light and dark values, retimes it,
scales it and turns it. Two-beat clips (a slash into a blast, for example) become combined effects.

The other 89 library effects are composed from tuned building blocks (or, for combos such as Cross Slash and Meteor Strike, from other effects) that follow the same rules: hits land in one
frame, rings race out and ease off, flashes carry size with shape rather than flat white blobs, every effect keeps a
white core, a saturated body and a deep tone so it recolours cleanly, and things that break leave something behind
(smoke, embers, scorch, debris). Some use real geometry: faceted crystal and rock spikes, coins, leaves, petals,
jagged lightning. Hits have a real hot frame: a 1-2 frame impact stamp with a solid core that still reads against a
bright sky, layered shock sheets flat to the strike, smoke puffs and a dim linger. The generator composes showcase
pieces from layers the same way, with a soft bloom while they play.

**Cutscenes:** depth of field follows the subject and is sized from the shot (close-ups blur the background, wide
shots stay sharp), a mood grade per template (boss, victory, defeat, reveal), a layered handheld drift, crash zooms
on impacts, 2.39:1 letterbox bars sized to the screen, and a title card that wipes in, lands with a sheen and a small
shake, then leaves fast. In a game the other UI hides while it plays and the camera blends back to gameplay.

**Models:** weapons follow stylised proportions (a one-handed sword is about 4 studs with a 1:8 blade and a guard
3.5 times the blade width), with bright edge bevels, a darker fuller, grip wraps, gems in glass, and three value
groups (light blade, mid trim, dark grip). Every weapon carries a swing trail from the blade's base to its tip, and
glowing ones a light and a few sparkles.

**Cutscenes from a clip:** colour-histogram cut detection (flashes and fades are told apart from cuts), camera
motion per shot from tracked features (push in, pull out, orbit, tilt, locked off), shot size from the body pose
(close-up, medium, full, wide), hand-held shake from the jitter left after smoothing, white flashes and fades to
black. Each shot is re-shot around your character on the clip's timing, scaled to the character's size.

## Tips & limits

- **Clips for animation:** one person, the whole body visible, a steady camera, 3-20 s. Use start/end to pick the
  moment. Fast spins, heavy occlusion, baggy costumes and cuts lower the quality.
- **VFX** reads as an interpretation in the closest professional style. It is not a frame-perfect copy. Steer it
  with the style chips or a phrase.
- Some Instagram/TikTok posts need a login. Export `cookies.txt` from your browser and set `CLIPFORGE_COOKIES` to its
  path before starting the server.
- Only use clips you have the right to use. Dances and choreography can be protected. Downloads happen only
  on your PC, for analysis, and follow each platform's rules.
- Effect textures are public Roblox images owned by their uploaders, and their terms apply. Check that every
  texture loads in a published game before you ship it.

## Project layout

```
.claude-plugin/    Claude Code plugin manifest + marketplace entry
skills/clipforge/  the skill Claude follows (setup, jobs, Studio, troubleshooting)
commands/          slash commands: setup, make, clip, anim, vfx, generate, cutscene, model, server, jobs, studio
.mcp.json          registers the ClipForge MCP server (scripts/clipforge-mcp.cmd)
plugin/src/        Studio plugin (Luau): init.server.luau, UI, Tab* (VFX, Scenes, Models, Settings), FX, Anim, TryTool,
                   Bridge, Installer, Prompt, Recolor, Blocks, Library (100 effects), Generator, Cutscene, Abilities,
                   ModelKit, VFXTimeline + Recipes/ (from vfxmith, MIT)
server/clipforge/  bot server (Python): server, jobs, router (words -> what to make), text_motion (the move
                   library), words (word forms), fetch, pose, motion, vfx_analyze, prompts, catalog (+ the
                   catalog.json build_plugin.py writes from the plugin source), cutscene_video, mcp_server
server/tests/      test_motion, test_vfx, test_catalog, test_cutscene_video, test_text_motion, test_server
                   (python tests/<name>.py)
scripts/           build_plugin.py (packs plugin/src into dist/ClipForge.rbxmx, --install; refreshes
                   server/clipforge/catalog.json), clipforge-mcp.cmd
examples/          discord_bot.py
docs/              PUBLISHING.md (GitHub upload, install, updates)
```

Credits: the effect runtime and base recipes come from [vfxmith](https://github.com/Frxctured/roblox-vfxmith), used
under the MIT license; see `THIRD_PARTY_NOTICES.md`. ClipForge also uses MediaPipe, OpenCV, NumPy and yt-dlp.
