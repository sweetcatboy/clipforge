# ClipForge one-time setup: Python environment, dependencies and the pose model.
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
# Everything ClipForge installs lives in %USERPROFILE%\.clipforge (override with CLIPFORGE_HOME): the Python
# environment (a short path: MediaPipe's files are nested deep enough to break Windows' 260-character limit inside
# long folders), the pose model, jobs and the bot token. Updating or moving the ClipForge folder keeps them.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$server = Join-Path $root "server"
$cfHome = if ($env:CLIPFORGE_HOME) { $env:CLIPFORGE_HOME } else { Join-Path $env:USERPROFILE ".clipforge" }
$venv = Join-Path $cfHome "venv"
$py = Join-Path $venv "Scripts\python.exe"

function Invoke-Native([string]$what, [scriptblock]$cmd) {
    & $cmd
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit code $LASTEXITCODE)" }
}

Write-Host "== ClipForge setup ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force $cfHome | Out-Null

# 1. uv (manages Python without touching your system install)
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "uv was not found. Installing it with winget (you may be asked to accept the source agreement)..."
    winget install --id astral-sh.uv -e
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        throw "uv is still not on PATH. Open a new PowerShell window and run setup.ps1 again."
    }
}

# 2. ffmpeg (yt-dlp uses it to merge and trim downloads)
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ffmpeg was not found. Install it with:  winget install Gyan.FFmpeg   (then reopen PowerShell)" -ForegroundColor Yellow
}

# 3. Python 3.12 virtual environment + packages (MediaPipe needs Python 3.9-3.12)
if (-not (Test-Path $py)) {
    uv venv --python 3.12 $venv
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $py)) {
        # Sandboxed shells (packaged apps) can't always use uv's shared Python folder: keep a private copy.
        Write-Host "Retrying with a private Python install in $cfHome\python ..." -ForegroundColor Yellow
        if (Test-Path $venv) { Remove-Item -Recurse -Force $venv }
        $env:UV_PYTHON_INSTALL_DIR = Join-Path $cfHome "python"
        Invoke-Native "Creating the Python 3.12 environment" { uv venv --python 3.12 $venv }
    }
}
Invoke-Native "Installing Python packages" { uv pip install --python $py -r (Join-Path $server "requirements.txt") }

# 4. MediaPipe pose model (heavy = most accurate)
$models = Join-Path $cfHome "models"
New-Item -ItemType Directory -Force $models | Out-Null
$model = Join-Path $models "pose_landmarker_heavy.task"
if (-not (Test-Path $model)) {
    Write-Host "Downloading the MediaPipe pose model (~30 MB)..."
    $url = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/latest/pose_landmarker_heavy.task"
    Invoke-WebRequest -Uri $url -OutFile $model -UseBasicParsing
}

& $py -c "import mediapipe, cv2, yt_dlp; from mediapipe.tasks.python import vision; print('ClipForge deps OK: mediapipe', mediapipe.__version__)"
if ($LASTEXITCODE -ne 0) { throw "The Python packages did not import correctly." }

Write-Host ""
Write-Host "Setup complete. Start the bot server with:  .\start-server.ps1" -ForegroundColor Green
