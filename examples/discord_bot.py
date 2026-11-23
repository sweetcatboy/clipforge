"""Example Discord bot for ClipForge: people post a clip link or just say what they want, Roblox Studio builds it.

    !make <anything>      reads the words: "fire punch", "backflip", "kamehameha", "glowing katana",
                          "boss intro cutscene"... (also: mention the bot with your request)
    !clip <link>          animation + VFX from a YouTube / TikTok / Instagram / X link
    !anim <link or words> animation from a clip (optional start-end seconds) or from words ("jab then cross")
    !vfx  <link or text>  VFX from a clip, or from a description ("huge purple lightning slash", "coin burst")
    !gen  <text>          a showcase VFX from the generator ("golden glowing cube with light wings")
    !cutscene <text|link> a cutscene from a description ('boss intro "You dare?"') or a clip's camera work
    !model <text>         a weapon or prop ("glowing purple katana")

Setup:  <venv>\\Scripts\\python.exe -m pip install discord.py
        set DISCORD_TOKEN=<your bot token>      (enable the Message Content intent for the bot)
        python examples/discord_bot.py
Needs the ClipForge bot server running and the ClipForge plugin's Bot Link on in Studio.
For a bot on another machine: start-server.ps1 -Public, set CLIPFORGE_URL and CLIPFORGE_TOKEN.
"""
import asyncio
import json
import os
import re
import urllib.error
import urllib.request

import discord

API = os.environ.get("CLIPFORGE_URL", "http://127.0.0.1:7313").rstrip("/")
BOT_TOKEN = os.environ.get("CLIPFORGE_TOKEN", "")
LINK = re.compile(r"https?://\S+")
RANGE = re.compile(r"\b(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)\b")
COMMANDS = ("!make", "!clip", "!anim", "!vfx", "!gen", "!cutscene", "!model")


def call(method, path, body=None, timeout=330):
    headers = {"Content-Type": "application/json"}
    if BOT_TOKEN:
        headers["Authorization"] = "Bearer " + BOT_TOKEN
    req = urllib.request.Request(API + path, data=json.dumps(body).encode() if body is not None else None,
                                 method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"status": "failed", "error": json.loads(e.read().decode()).get("error", str(e))}


intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)


def payload_for(cmd: str, rest: str):
    """(payload, None) for a job, or (None, help text)."""
    link = LINK.search(rest)
    payload = {"client": "discord", "options": {}}
    if cmd == "!make":
        if not rest:
            return None, "Say what you want, e.g. `!make fire punch`, `!make backflip`, `!make glowing katana`"
        if link:  # a clip: read both the body motion and the effect
            payload.update(source=link.group(0), kind="both")
        else:
            payload.update(prompt=rest, kind="auto")
    elif cmd in ("!gen", "!model"):
        if not rest:
            return None, "Describe it, e.g. `!gen golden glowing cube with light wings` or `!model glowing purple katana`"
        payload.update(prompt=rest, kind="generate" if cmd == "!gen" else "model")
    elif cmd == "!cutscene":
        if not rest:
            return None, 'Describe it, e.g. `!cutscene boss intro "You dare challenge me?"`, or post a trailer link'
        payload.update(kind="cutscene", prompt=rest.replace(link.group(0), "").strip() if link else rest)
        if link:
            payload["source"] = link.group(0)
    elif cmd in ("!vfx", "!anim") and not link:
        if not rest:
            return None, ("Describe an effect, e.g. `!vfx huge purple lightning slash`" if cmd == "!vfx" else
                          "Name a move, e.g. `!anim uppercut` or `!anim jab then cross then hook`, or post a link")
        payload.update(prompt=rest, kind="vfx" if cmd == "!vfx" else "animation")
    elif not link:
        return None, "Post a link, e.g. `!clip https://www.tiktok.com/@someone/video/123`"
    else:
        payload.update(source=link.group(0), kind={"!clip": "both", "!anim": "animation", "!vfx": "vfx"}[cmd])
        span = RANGE.search(rest.replace(link.group(0), ""))
        if span:
            payload["options"].update(start=float(span.group(1)), end=float(span.group(2)))
    return payload, None


@client.event
async def on_message(msg: discord.Message):
    if msg.author.bot:
        return
    text = msg.content.strip()
    cmd = text.split(" ", 1)[0].lower()
    if cmd in COMMANDS:
        rest = text[len(cmd):].strip()
    elif client.user and client.user in msg.mentions:  # "@ClipForge make me a fire punch"
        cmd, rest = "!make", re.sub(r"<@!?\d+>", "", text).strip()
    else:
        return
    payload, help_text = payload_for(cmd, rest)
    if payload is None:
        return await msg.reply(help_text)
    job = await asyncio.to_thread(call, "POST", "/api/jobs", payload)
    if "id" not in job:
        return await msg.reply(f"Could not start: {job.get('error')}")
    note = await msg.reply(f"On it (job `{job['id']}`)...")
    done = await asyncio.to_thread(call, "GET", f"/api/jobs/{job['id']}?wait=300")
    if done.get("status") == "done":
        await note.edit(content=f"Done: {done.get('message')}. It is being built in Roblox Studio.")
    else:
        await note.edit(content=f"Failed: {done.get('error') or done.get('status')}")


if __name__ == "__main__":
    client.run(os.environ["DISCORD_TOKEN"])
