---
description: Start, stop or check the ClipForge bot server (the plugin and bots talk to it)
argument-hint: "[start|stop|status|restart|public]"
---

Use the `clipforge` skill (ClipForge plugin) to manage the bot server: $ARGUMENTS (default: status)

- **status:** `Invoke-RestMethod http://127.0.0.1:7313/api/health`, plus the count of active jobs. If it doesn't
  answer, say it is stopped.
- **start:** if it is not already running, run `powershell -ExecutionPolicy Bypass -File "<ROOT>\start-server.ps1"`
  in the background and poll health until it answers. Tell the user it keeps running in the background of this
  session; to keep it running after the session, they run `start-server.ps1` in their own PowerShell window.
- **public:** the same, with `-Public`. Then show the token from `<CF_HOME>\data\bot_token.txt` and say that bots on
  other machines must send `Authorization: Bearer <token>`.
- **stop:** find the process with
  `(Get-NetTCPConnection -LocalPort 7313 -State Listen).OwningProcess` and stop it. Confirm it is gone.
- **restart:** stop, then start.
