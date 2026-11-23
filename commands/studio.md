---
description: Install or update the ClipForge plugin in Roblox Studio (or build the .rbxmx to share)
argument-hint: "[install|build]"
---

Use the `clipforge` skill (ClipForge plugin): $ARGUMENTS (default: install)

- **install:** `& "<PY>" "<ROOT>\scripts\build_plugin.py" --install`. This writes
  `%LOCALAPPDATA%\Roblox\Plugins\ClipForge.rbxmx`, and open Studio windows reload it within a few seconds. Then tell
  the user: Plugins tab > ClipForge, allow 127.0.0.1 when Studio asks, and turn on Bot Link in the Bots tab to
  receive bot jobs.
- **build:** `& "<PY>" "<ROOT>\scripts\build_plugin.py"`. It writes `<ROOT>\dist\ClipForge.rbxmx` to share, for
  example attached to a GitHub release, or saved as a Creator Store plugin from Studio.

If `<PY>` does not exist yet, run `/clipforge:setup` first. The build needs only Python, so any Python 3 works for
it too.
