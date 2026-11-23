"""Example Discord bot for ClipForge: people post a clip link, Roblox Studio builds the animation/VFX.

    !clip <link>          animation + VFX from a YouTube / TikTok / Instagram / X link
    !anim <link> [3-9]    animation only (optional start-end seconds)
    !vfx  <link or text>  VFX from a clip, or from a description ("huge purple lightning slash")

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


@client.event
async def on_message(msg: discord.Message):
    if msg.author.bot:
        return
    text = msg.content.strip()
    cmd = text.split(" ", 1)[0].lower()
    if cmd not in ("!clip", "!anim", "!vfx"):
        return
    rest = text[len(cmd):].strip()
    link = LINK.search(rest)
    payload = {"client": "discord", "options": {}}
    if cmd == "!vfx" and not link:
        if not rest:
            return await msg.reply("Describe an effect, e.g. `!vfx huge purple lightning slash`")
        payload.update(prompt=rest, kind="vfx")
    elif not link:
        return await msg.reply("Post a link, e.g. `!clip https://www.tiktok.com/@someone/video/123`")
    else:
        payload.update(source=link.group(0), kind={"!clip": "both", "!anim": "animation", "!vfx": "vfx"}[cmd])
        span = RANGE.search(rest.replace(link.group(0), ""))
        if span:
            payload["options"].update(start=float(span.group(1)), end=float(span.group(2)))
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
