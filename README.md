# ClipForge: video to Roblox animation & VFX

ClipForge is a Roblox Studio plugin and a local "bot server". It turns clips from YouTube (and Shorts), TikTok,
Instagram Reels, X, Reddit, Twitch clips and more, or a video file, into:

- **Animations**: the person's body motion becomes a `KeyframeSequence` for your rig (R15 or R6, any
  proportions, classic `Motor6D` or the newer `AnimationConstraint` joints).
- **VFX**: the clip's effect (a slash, a slam, an explosion, an aura...) is read for its palette, timing, motion and
  shape. ClipForge then builds a layered effect in that style from studied professional recipes.

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
| `/clipforge:clip <link> [animation\|vfx\|both] [3-9] [Name]` | Clip to animation and/or VFX, built in Studio |
| `/clipforge:anim <link> [loop] [mirror] [travel]` | Animation only |
| `/clipforge:vfx <description or link>` | VFX from a description ("huge purple lightning slash") or a clip |
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
| **Create** | Paste a link (or a file path), pick Animation / VFX / Both, optionally a start/end time, press **Generate**. Animation options: In place / Travels / Locked root, Crisp / Smooth / Silky filtering, loop, mirror, face forward. VFX options: Auto or force a type, plus a steering text ("make it purple"). It builds itself when ready. |
| **Library** | 11 professional base effects (slash, ground slam, explosion, aura charge, beam, lightning, projectile, fire eruption, frost burst, void breach, holy burst). Describe one ("huge purple lightning slash"; works offline), recolour it with presets or hex codes, set size, speed and slash angle, preview it where the camera looks, then **Insert into game**. |
| **Animations** | Every generated animation: **Play** on the preview rig (select any character, or spawn an R15/R6 dummy), **Re-bake** on another rig, **Edit** in the Animation Editor, **Publish** to your account. |
| **Bots** | Server address and status, **Bot Link** (this Studio window builds what bots send), the job feed (who asked, what was made, where it went). |

Where things go in your place:

- `ReplicatedStorage.ClipForge`: the effect runtime (`FX`, `VFXTimeline`, `Recolor`, `Recipes`) and `Effects/`,
  one small config module per effect, editable by hand.
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
effect name and CFrame, then call `FX.play` there.

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
# a description -> VFX
curl -X POST http://127.0.0.1:7313/api/jobs -H "Content-Type: application/json" \
     -d '{"prompt": "huge purple lightning slash", "client": "my-bot"}'
# wait for it (long-poll up to 300 s)
curl "http://127.0.0.1:7313/api/jobs/<id>?wait=60"
```

| Endpoint | |
|---|---|
| `POST /api/jobs` | `source` (link or file path) and/or `prompt`, `kind` (`animation`/`vfx`/`both`), `name`, `client`, `options` (`start`, `end`, `rootMotion`: `inplace`/`full`/`none`, `smoothing` 0-1, `loop`, `mirror`, `lockFacing`, `speed`, `style`, `scale`) |
| `GET /api/jobs/{id}?wait=s` | status, progress, message, summary, `delivered` (built in Studio) |
| `GET /api/jobs/{id}/result` | the full animation keys / effect config |
| `GET /api/jobs/{id}/files/sheet.jpg` | contact sheet of what the VFX reader saw, with the palette |
| `GET /api/jobs` · `DELETE /api/jobs/{id}` · `GET /api/presets` · `GET /api/health` | |

Bots on another machine: run `.\start-server.ps1 -Public` and send `Authorization: Bearer <token>`. The token is in
`%USERPROFILE%\.clipforge\data\bot_token.txt`. Local requests need no token. Requests from web pages are refused, so a
website can't drive your server.

**MCP (AI agents):** tools `clipforge_from_video`, `clipforge_vfx_from_prompt`, `clipforge_job_status`,
`clipforge_list_jobs`, `clipforge_presets`. If no bot server is running, the MCP server starts one. The Claude Code
plugin registers it for you (`.mcp.json`). To add it by hand to Claude Code:

```powershell
claude mcp add clipforge --env PYTHONPATH="<this folder>\server" -- "$env:USERPROFILE\.clipforge\venv\Scripts\python.exe" -m clipforge mcp
```

JSON clients (Claude Desktop, Cursor): `"command": "<user>\\.clipforge\\venv\\Scripts\\python.exe"`,
`"args": ["-m", "clipforge", "mcp"]`, `"env": {"PYTHONPATH": "<this folder>\\server"}`.

**CLI:** `python -m clipforge make <link> --kind both --start 3 --end 9`, or
`python -m clipforge make --prompt "small holy heal"`. Run it from `server\` with the venv's python.

**Discord:** `examples/discord_bot.py` is a ready-made bot with `!clip`, `!anim` and `!vfx` commands.

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

**VFX:** effects are not traced from the video. The clip is *measured*:

- the glow palette: white core, saturated body, deep tone;
- the rhythm: wind-up, hit, decay, beats;
- the motion signature: bursting out, sucking in, sweeping, rising, travelling, flickering;
- the shape: round or long.

Those numbers pick and fit one of 11 professional base recipes. Each recipe was distilled from roughly 1,200
studied open-source Roblox effects: layered impact frames with ink twins, flipbooks, racing rings, smoke,
embers, scorch marks. ClipForge recolours a recipe without flattening its light and dark values, retimes it,
scales it and turns it. Two-beat clips (a slash into a blast, for example) become combined effects.

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
commands/          slash commands: setup, clip, anim, vfx, server, jobs, studio
.mcp.json          registers the ClipForge MCP server (scripts/clipforge-mcp.cmd)
plugin/src/        Studio plugin (Luau): init.server.luau, UI, FX, Anim, Bridge, Installer, Prompt, Recolor,
                   VFXTimeline + Recipes/ (from vfxmith, MIT)
server/clipforge/  bot server (Python): server, jobs, fetch, pose, motion, vfx_analyze, prompts, mcp_server
server/tests/      motion round-trip tests, VFX reader tests (python tests/test_motion.py, tests/test_vfx.py)
scripts/           build_plugin.py (packs plugin/src into dist/ClipForge.rbxmx, --install), clipforge-mcp.cmd
examples/          discord_bot.py
docs/              PUBLISHING.md (GitHub upload, install, updates)
```

Credits: the effect runtime and base recipes come from [vfxmith](https://github.com/Frxctured/roblox-vfxmith), used
under the MIT license; see `THIRD_PARTY_NOTICES.md`. ClipForge also uses MediaPipe, OpenCV, NumPy and yt-dlp.
