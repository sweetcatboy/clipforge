---
description: List recent ClipForge jobs (who asked, status, whether Studio has built them)
argument-hint: "[count] | <job id>"
---

Use the `clipforge` skill (ClipForge plugin): $ARGUMENTS

- **A job id:** show that job (`clipforge_job_status` MCP tool, or `GET /api/jobs/<id>`): status, message or error,
  summary, and whether Studio built it (`delivered`, `deliveredInfo`). For a VFX job, describe its contact sheet
  `<CF_HOME>\data\jobs\<id>\sheet.jpg`.
- **Otherwise:** list the last N jobs (default 10) with `clipforge_list_jobs` or `GET /api/jobs?limit=N`, as a compact
  table: name, kind, from (client), status, built in Studio yes/no.

If jobs are done but not built, remind the user to open the ClipForge widget in Studio and turn on Bot Link. If a job has a `buildError`, Studio tried and failed: show the error and suggest `/clipforge:studio install`, then **Build here** on that job in the plugin's Bots tab.
