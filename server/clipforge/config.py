"""Paths, version and the bot token."""
from __future__ import annotations

import os
import secrets

VERSION = "1.1.0"
SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Everything that must survive updates (Python env, pose model, jobs, bot token) lives in CLIPFORGE_HOME
# (default %USERPROFILE%\.clipforge), not next to the code: a Claude Code plugin update replaces the code folder.
HOME = os.environ.get("CLIPFORGE_HOME") or os.path.join(os.path.expanduser("~"), ".clipforge")
MODELS_DIR = os.path.join(HOME, "models")
MODEL_DIRS = [MODELS_DIR, os.path.join(SERVER_DIR, "models")]
DATA_DIR = os.environ.get("CLIPFORGE_DATA", os.path.join(HOME, "data"))
JOBS_DIR = os.path.join(DATA_DIR, "jobs")
CACHE_DIR = os.path.join(DATA_DIR, "cache")
TOKEN_FILE = os.path.join(DATA_DIR, "bot_token.txt")
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = int(os.environ.get("CLIPFORGE_PORT", "7313"))
MAX_VIDEO_SECONDS = float(os.environ.get("CLIPFORGE_MAX_SECONDS", "60"))


def ensure_dirs() -> None:
    for d in (DATA_DIR, JOBS_DIR, CACHE_DIR):
        os.makedirs(d, exist_ok=True)


def bot_token() -> str:
    """Shared secret for bots that connect from another machine (local requests don't need it)."""
    ensure_dirs()
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, "r", encoding="utf-8") as f:
            tok = f.read().strip()
            if tok:
                return tok
    tok = secrets.token_urlsafe(24)
    with open(TOKEN_FILE, "w", encoding="utf-8") as f:
        f.write(tok)
    return tok
