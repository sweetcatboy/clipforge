@echo off
rem ClipForge MCP server launcher (stdio). Claude Code starts it from .mcp.json; stdout must carry only JSON-RPC.
setlocal
if defined CLIPFORGE_HOME (set "CF=%CLIPFORGE_HOME%") else (set "CF=%USERPROFILE%\.clipforge")
if not exist "%CF%\venv\Scripts\python.exe" (
  echo ClipForge is not set up yet: run /clipforge:setup, then reconnect the clipforge MCP server with /mcp. 1>&2
  exit /b 1
)
set "PYTHONPATH=%~dp0..\server"
set "PYTHONIOENCODING=utf-8"
"%CF%\venv\Scripts\python.exe" -m clipforge mcp
