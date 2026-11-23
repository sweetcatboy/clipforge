# Starts the ClipForge bot server (keep this window open while you use the plugin's Create tab or Bot Link).
#   .\start-server.ps1            local only (Studio plugin, local bots, MCP)
#   .\start-server.ps1 -Public    also reachable from other machines (bots must send the token it prints)
param([switch]$Public, [int]$Port = 7313)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfHome = if ($env:CLIPFORGE_HOME) { $env:CLIPFORGE_HOME } else { Join-Path $env:USERPROFILE ".clipforge" }
$py = Join-Path $cfHome "venv\Scripts\python.exe"
if (-not (Test-Path $py)) { Write-Host "Run setup.ps1 first." -ForegroundColor Yellow; exit 1 }
$env:CLIPFORGE_PORT = "$Port"
Push-Location (Join-Path $root "server")
try {
    if ($Public) { & $py -m clipforge serve --port $Port --public } else { & $py -m clipforge serve --port $Port }
} finally { Pop-Location }
