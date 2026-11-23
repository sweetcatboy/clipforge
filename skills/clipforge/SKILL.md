---
name: clipforge
description: Make Roblox animations, VFX, generated showcase VFX, cutscenes and weapon/prop models from social-media videos (YouTube, Shorts, TikTok, Instagram Reels, X/Twitter, Reddit, Twitch clips, a local video file) or from plain words, using ClipForge (bot server + Roblox Studio plugin with a 100-effect library and a hand-keyed move library). Use for "turn this TikTok/YouTube dance into a Roblox animation", "make a fire punch", "make me a backflip animation", "make a VFX like this video", "make a huge purple lightning slash effect", "generate a golden cube with wings", "make a boss intro cutscene", "copy the camera work of this trailer", "make a glowing katana", setting up or fixing ClipForge, its bot server, the Studio plugin, Bot Link, or connecting a Discord/AI bot to it.
---

# ClipForge

ClipForge has three parts:

- a local **bot server** (Python) that downloads clips, tracks body pose and reads VFX;
- a **Roblox Studio plugin** that builds the results in the user's place;
- **MCP tools**: `clipforge_make` (any request in plain words), `clipforge_animation_from_prompt`,
  `clipforge_from_video`, `clipforge_vfx_from_prompt`, `clipforge_generate_vfx`, `clipforge_make_cutscene`,
  `clipforge_make_model`, `clipforge_job_status`, `clipforge_list_jobs`, `clipforge_presets` (everything Studio can
  build: the 100 effects, the animation moves, generator options, cutscene templates, models).

Windows only.

Paths (resolve them once, quote them, they may contain spaces):
- `ROOT` = this skill's base directory `/../..` (the plugin root, also `${CLAUDE_PLUGIN_ROOT}`).
- `CF_HOME` = `$env:CLIPFORGE_HOME`, else `$env:USERPROFILE\.clipforge`. It holds the Python venv, the pose model,
  jobs and the bot token.
- `PY` = `CF_HOME\venv\Scripts\python.exe`.
- Server: `http://127.0.0.1:7313` (`$env:CLIPFORGE_PORT` overrides).

Use PowerShell for every command below.

## 0. Ready check (before any job; quick)

1. **Set up?** `Test-Path "$env:USERPROFILE\.clipforge\venv\Scripts\python.exe"`. If not, do section 1 first.
2. **Server up?** `Invoke-RestMethod http://127.0.0.1:7313/api/health` must return `name = ClipForge`.
   - If not, start it in the background (keep it running): `powershell -ExecutionPolicy Bypass -File "<ROOT>\start-server.ps1"`.
   - Poll health once a second for up to 20 s.
   - If the MCP tools are connected, they start a server inside the MCP process by themselves.
3. **Studio plugin installed?** `Test-Path "$env:LOCALAPPDATA\Roblox\Plugins\ClipForge.rbxmx"`. If not, do section 1 step 3.

## 1. Setup (`/clipforge:setup`)

1. `powershell -ExecutionPolicy Bypass -File "<ROOT>\setup.ps1"`. Run it in the background and wait: it creates the
   Python 3.12 env with uv, installs MediaPipe, OpenCV and yt-dlp, and downloads the pose model. It takes a few
   minutes the first time.
   - If `uv` is missing, the script installs it with winget, which asks the user first.
   - `ffmpeg` is needed. If the script warns that it is missing, tell the user to run `winget install Gyan.FFmpeg`
     and reopen the terminal.
2. Check: `& "<PY>" -c "import mediapipe, cv2, yt_dlp; print('ok')"`.
3. Studio plugin: `& "<PY>" "<ROOT>\scripts\build_plugin.py" --install`. This writes
   `%LOCALAPPDATA%\Roblox\Plugins\ClipForge.rbxmx`, and Studio reloads local plugins on its own.
4. Start the server (section 0.2).
5. Tell the user:
   - "In Studio: Plugins tab > ClipForge, allow it to reach 127.0.0.1 when asked. Turn on **Bot Link** in the Bots tab
     so jobs made here build in that place."
   - If the `clipforge` MCP server showed as failed before setup, reconnect it with `/mcp`.
6. Tests, when the user asks for a check: `& "<PY>" "<ROOT>\server\tests\test_motion.py"` and
   `test_vfx.py` (run from `<ROOT>\server`).

## 2. Make things

Prefer the MCP tools when they are listed. Otherwise use the REST API:

```powershell
$body = @{ source = "<link or file path>"; kind = "both"; name = "DanceMove"; client = "claude"
           options = @{ start = 3; end = 9; rootMotion = "inplace"; loop = $true } } | ConvertTo-Json -Depth 5
$job = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:7313/api/jobs -ContentType "application/json" -Body $body
Invoke-RestMethod "http://127.0.0.1:7313/api/jobs/$($job.id)?wait=240"     # long-poll until done/failed
```

- **Any request in plain words:** `{ "prompt": "fire punch" }` (or `clipforge_make`). `kind` defaults to `auto`:
  the server reads the words and makes an animation, an effect, both (linked as an ability: the effect fires on the
  animation's Hit frame, with hit-stop and camera shake), a generated piece, a model or a cutscene. "fire punch" =
  a punch + a fire impact; "backflip" = an animation; "kamehameha" = the beam move + its beam; "chain lightning" or
  "coin burst" = an effect; "glowing katana" = a model; "boss intro" = a cutscene. `POST /api/preview` with the same
  body says what it would make without making it (MCP: `preview: true`).
- **Animations from words:** `{ "prompt": "uppercut", "kind": "animation" }` (or `both` to add the effect and the
  ability). Moves: punches (jab, cross, hook, uppercut), kicks (front, roundhouse), sword (slash, thrust, overhead,
  spin), powers (cast, power-up, beam, throw, ground pound), block, movement (idle, fighting stance, walk, run,
  sprint, jump, backflip, front flip, dash, dodge roll), reactions (hit, knockdown, dizzy), emotes (wave, cheer,
  dance, clap, bow, point, salute, shrug, flex, laugh, victory pose, sad) and combos (punch, sword, kick). "then" or
  commas chain moves ("jab then cross then hook"). Words: fast/slow (speed), heavy/huge/light (power), left or
  mirror, loop. `options`: `speed`, `loop`, `mirror`. They are hand-keyed (anticipation, snappy strikes, hit holds,
  follow-through, overlap) and baked onto any R15 or R6 rig.
- **From a clip:** `kind` is `animation` (body motion), `vfx` (the effect in it) or `both`. Body tracking runs at
  roughly real time on a CPU: a 15 s clip takes about 0.5-2 min, so tell the user it is working.
- **From a description:** `{ "prompt": "huge purple lightning slash", "kind": "vfx" }` returns in about a second.
  It picks from the 100-effect library (an effect named outright wins: "coin burst", "chain lightning", "level up";
  then the closest kind) and recolours it from colour or element words ("ice slam" = an icy ground slam; an effect
  keeps its own colours when the words describe it, as in "poison cloud"). A prompt next to a `source` steers the
  VFX read ("make it purple", "slash").
- **Generated showcase VFX:** `{ "kind": "generate", "prompt": "golden glowing cube with light wings" }`. It composes
  a hero (glowing cube, wireframe cube, crystal, orb) with frames (orbit rings, wings, heart, halo, rune circle),
  energy (light shafts, rays, lightning arcs, swirl) and atmosphere (nebula, stars, floating squares, petals,
  leaves, smoke, embers), or an impact or black-hole vortex. `options`: `mode` (`showcase`/`impact`/`vortex`),
  `chromatic` (rainbow RGB-split fringes), `seed` (another variation of the same idea: use the last seed + 1).
  Use it for portfolio/showcase pieces and big set pieces; use `vfx` for ordinary attacks and elements.
- **Cutscenes:** `{ "kind": "cutscene", "prompt": "boss intro \"You dare challenge me?\"" }` picks a template (boss
  intro, victory, dramatic reveal, ability showcase, map flyover, dialogue, defeat); quoted text becomes dialogue;
  an effect named in the words fires on the beat. With a `source` clip it copies the clip's cuts, camera moves,
  shot sizes, shake, flashes and fades instead (takes about as long as the clip). `options`: `who` (the actor
  the shots film, default `Target`), `template`, `title`, `effect`, `start`/`end`.
- **Models:** `{ "kind": "model", "prompt": "glowing purple katana" }`: sword, katana, greatsword, dagger, axe,
  spear, staff, wand, scythe, hammer, shield, magic orb, crystal cluster, rock, meteor, portal, rune totem; `options`
  `style` (steel, dark, gold, crystal, energy, wood), `glow` (#RRGGBB), `scale`.
- Turn the user's words into `options`:

| User says | options |
|---|---|
| only part of the clip ("3 to 9 s", "the jump at 0:12") | `start`, `end` in seconds |
| loop / idle / dance loop | `loop: true` |
| mirror / other hand | `mirror: true` |
| walks or runs across, travel | `rootMotion: "full"` (default `inplace` keeps sway, drops travel; `none` locks hips) |
| attack, emote, must face forward | `lockFacing: true` |
| jittery / smoother / snappier | `smoothing` 0.25 crisp, 0.5 default, 0.8 silky |
| a VFX type ("it's a slash", "explosion") | `style`: slash, impact, explosion, aura, beam, lightning, projectile, fire, ice, dark, holy |
| bigger / smaller, faster / slower effect | `scale` (1 = default, 1.6 huge), `speed` |

- Name things in PascalCase when the user gives a name (`name`). Otherwise ClipForge uses the clip title.

## 3. Getting it into Studio

The plugin builds finished jobs by itself in any Studio window where:

- the ClipForge widget is open and **Bot Link** is on (Bots tab), or
- the job was started from the plugin's Create tab.

Results go to:

- **VFX:** `ReplicatedStorage.ClipForge.Effects.<Name>`, a small config module, plus the runtime `FX`, `VFXTimeline`,
  `Recolor` and `Recipes`. In a LocalScript:
  `require(game.ReplicatedStorage.ClipForge.FX).play("<Name>", cframe)`.
- **Animation:** `ServerStorage.ClipForge.Animations.<Name>`, a KeyframeSequence. `MotionData` holds the raw motion for
  re-baking (long clips are split into `Part1`, `Part2`... children). A copy goes to
  `ServerStorage.RBX_ANIMSAVES.<rig>` for the Animation Editor. The plugin's **Anim > Publish** uploads it and returns
  an asset id. A clip with both an animation and a VFX also gets an ability in
  `ReplicatedStorage.ClipForge.Abilities` that fires the effect on the detected hit; words with both ("fire punch")
  get one that fires on every Hit marker, with hit-stop. In a LocalScript:
  `require(game.ReplicatedStorage.ClipForge.Abilities).play("<Name>Ability", character, { animationId = "rbxassetid://<published id>" })`.
- **Generated VFX:** a config module in `ReplicatedStorage.ClipForge.Effects` like any effect (plays with `FX.play`).
- **Cutscene:** `ReplicatedStorage.ClipForge.Cutscenes.<Name>`. It also opens in the plugin's **Scenes** tab for
  preview. In a LocalScript:
  `require(game.ReplicatedStorage.ClipForge.Cutscene).play("<Name>", { actors = { Target = workspace.Boss } })`.
- **Model:** built in the workspace where the camera looks. The **Models** tab attaches it to a rig, makes it a Tool
  (StarterPack) or saves it to `ReplicatedStorage.ClipForge.Models`.

If the Roblox Studio MCP is connected, you may check that the instances exist (read only). Ask before changing
the user's place.

## 4. Report back

Say what was made, its name and where it is in Studio. For VFX, also give:

- the archetype and confidence from `summary.vfx`;
- the palette hex codes;
- the contact sheet of what the reader saw, `CF_HOME\data\jobs\<id>\sheet.jpg`. Open it with Read and describe it
  in one line.

For animations from a clip, also give the duration, the key count and `quality.detectedRatio`. Below 0.8, suggest a
clip where the whole body stays in frame. For animations from words, give the move(s) and duration from the job
`message`, and say that the Hit marker drives effects, hit-stop and damage timing (`track:GetMarkerReachedSignal("Hit")`).

For generated VFX, models and prompt cutscenes, the job `message` already says what was made (mode and layers;
style, type and glow; template, lines and effect): repeat it plainly. For a cutscene from a clip, list the shots
(`summary.cutscene` / the result's `analysis.shots`: time, move, size) and the counts of flashes, shakes and fades.

If the job's `delivered` flag is false, remind the user to turn on Bot Link in Studio. If it has a `buildError`,
Studio tried and failed: give the error, suggest updating the Studio plugin (`/clipforge:studio install`), then
**Build here** on the job in the plugin's Bots tab.

## 5. Troubleshooting

| Symptom | Fix |
|---|---|
| "No person was detected" | One person, whole body visible, steady camera. Trim with `start`/`end` to the clean part. A `both` job still delivers the VFX. |
| Download error mentioning login, cookies or private | The post needs a login. The user exports `cookies.txt` from their browser and sets `CLIPFORGE_COOKIES=<path>` before starting the server. Never read browser cookie stores yourself. |
| Studio: "Http requests are not enabled" or no build | Allow ClipForge in Studio's Plugin Management (HTTP to 127.0.0.1), open the widget, press Connect, turn on Bot Link. |
| Port 7313 busy | Another server is running (fine), or set `CLIPFORGE_PORT` and the plugin's server address to match. |
| MediaPipe import fails with a missing module | Path too long: the venv must stay in `CF_HOME` (short path). Re-run setup. |
| Effect looks too small or big, or too fast | Rerun with `scale`/`speed`, or edit the numbers in the effect's config module. |
| Job done but `buildError` / "Paused" | Studio could not build it (an older plugin retries forever, so the server pauses a job after 3 failed builds). Update the plugin, then press **Build here** on the job (it always retries). |
| A cutscene films the wrong spot | Its shots follow the actor named `who` (default `Target`): play it with `actors = { Target = <model> }`, or select the model in the Scenes tab and press Use selection. |

## 6. Bots

- Any bot posts to `POST /api/jobs` (fields in `ROOT\README.md`; options listed by `GET /api/catalog`).
  `ROOT\examples\discord_bot.py` is a ready-made Discord bot with `!make` (any words; mentioning the bot works too),
  `!clip`, `!anim` (a link or words), `!vfx`, `!gen`, `!cutscene` and `!model`.
- Bots on another machine need `start-server.ps1 -Public` and `Authorization: Bearer <CF_HOME\data\bot_token.txt>`.
- Requests that carry a browser `Origin` header are refused, so a website can't drive the server.

Only use clips the user has the right to use. Downloads stay on this PC, for analysis only.
