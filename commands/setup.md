---
description: Set up ClipForge on this PC (Python env, pose model, Roblox Studio plugin, bot server)
argument-hint: "[check]  (check = only report what is missing)"
---

Use the `clipforge` skill (ClipForge plugin). Arguments: $ARGUMENTS

If the arguments say "check", run only the skill's section 0 ready check and report each part as ready or missing,
with the command that fixes it.

Otherwise run section 1 (Setup) step by step: setup.ps1 in the background (wait for it), the import check, build and
install the Studio plugin, start the bot server and confirm `/api/health`. Finish with the short "In Studio" note from
step 5, and say whether the `clipforge` MCP server needs a reconnect with `/mcp`.
