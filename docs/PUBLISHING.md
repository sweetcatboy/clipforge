# Publishing ClipForge on GitHub

This folder is already a Claude Code plugin **and** its own marketplace:

- `.claude-plugin/plugin.json` describes the plugin;
- `.claude-plugin/marketplace.json` lists it;
- `skills/`, `commands/` and `.mcp.json` hold the skill, the slash commands and the MCP server.

Once it is on GitHub, anyone installs it with two commands.

## 1. Before you upload (2 minutes)

- **Your name.** Edit `.claude-plugin/plugin.json` (`"author": { "name": "..." }`) and
  `.claude-plugin/marketplace.json` (`"owner": { "name": "..." }`). You can also add
  `"repository": "https://github.com/<you>/clipforge"` to `plugin.json`.
- **A license.** Without one, nobody may legally reuse your code.
  - On GitHub: **Add file > Create new file**, name it `LICENSE`, then **Choose a license template** (MIT is the
    common choice for plugins).
  - Keep `THIRD_PARTY_NOTICES.md`: the effect runtime and recipes come from vfxmith (MIT), and its notice must stay.
- **Secrets stay out.** `.gitignore` already excludes:
  - `server/data/` (jobs and the bot token);
  - `server/models/`;
  - `dist/` (build output);
  - `test/`.

  Your Python environment, pose model, jobs and token live in `%USERPROFILE%\.clipforge`, outside the repo.

## 2. Upload

### Option A: Git in PowerShell

1. On <https://github.com/new> create a repository named `clipforge`, set it to **Public**, and **don't** add a README,
   license or .gitignore (this folder has them).
2. In this folder:

```powershell
git init
git add .
git commit -m "ClipForge 1.0.0"
git branch -M main
git remote add origin https://github.com/<you>/clipforge.git
git push -u origin main
```

The first push opens a browser window to sign in to GitHub. If git asks who you are, run
`git config --global user.name "Your Name"` and `git config --global user.email "<you>@users.noreply.github.com"`.
GitHub's no-reply address keeps your real email private: find it under **Settings > Emails**.

### Option B: GitHub Desktop

**File > Add local repository**, pick this folder, choose **create a repository**, then **Publish repository**.

## 3. Install it in Claude Code (you or anyone)

```
/plugin marketplace add <you>/clipforge
/plugin install clipforge@clipforge
```

Then run `/clipforge:setup` once. It installs Python packages, the pose model, the Roblox Studio plugin and starts
the bot server. If Claude Code showed the `clipforge` MCP server as failed before setup, reconnect it with `/mcp`.

To test before publishing, `/plugin marketplace add C:\path\to\this\folder` works with a local folder too.

| Command | What it does |
|---|---|
| `/clipforge:setup [check]` | Install everything, or only report what is missing |
| `/clipforge:clip <link> [animation\|vfx\|both] [3-9] [Name]` | Clip to animation and/or VFX |
| `/clipforge:anim <link> [loop] [mirror] [travel]` | Animation only |
| `/clipforge:vfx <description or link>` | VFX from the 100-effect library or a clip |
| `/clipforge:generate <description>` | Showcase VFX from the generator |
| `/clipforge:cutscene <description or link>` | Cutscene from a description or a clip's camera work |
| `/clipforge:model <description>` | Weapon or prop model |
| `/clipforge:server [start\|stop\|status\|public]` | Manage the bot server |
| `/clipforge:jobs [n \| id]` | Recent jobs and whether Studio built them |
| `/clipforge:studio [install\|build]` | Install or update the Roblox Studio plugin, or build the `.rbxmx` |

Claude also uses the `clipforge` skill and the MCP tools on its own when someone asks for a Roblox animation or VFX
from a video.

## 4. Share the Studio plugin on its own (optional)

- **GitHub release:** run `/clipforge:studio build` (or `python scripts\build_plugin.py`). On GitHub open
  **Releases > Draft a new release**, tag the version (for example `v1.3.0`), and attach `dist\ClipForge.rbxmx`. People drop it into
  `%LOCALAPPDATA%\Roblox\Plugins`.
- **Creator Store:** insert `dist\ClipForge.rbxmx` into a place, right-click the `ClipForge` script and choose
  **Publish as Plugin**.

## 5. Updating

1. Change what you need, then bump `"version"` in `.claude-plugin/plugin.json` (for example `1.0.1`).
2. Run `git add .`, then `git commit -m "..."`, then `git push`.
3. Users update with `/plugin marketplace update clipforge`, then `/plugin update clipforge@clipforge`, then
   `/clipforge:studio install` to refresh the Studio plugin.
