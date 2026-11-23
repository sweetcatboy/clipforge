"""Package plugin/src into a Roblox model file (.rbxmx) and optionally install it as a local Studio plugin.

  python scripts/build_plugin.py                 -> dist/ClipForge.rbxmx
  python scripts/build_plugin.py --install       -> also copies it to %LOCALAPPDATA%\\Roblox\\Plugins
  python scripts/build_plugin.py --dev           -> also writes <Studio content>/clipforge/ClipForgeDev.rbxmx
                                                    (modules only, for loading with game:GetObjects in tests)

Layout: plugin/src/init.server.luau becomes the plugin Script "ClipForge"; every other .luau file becomes a
ModuleScript under it (folders become Folders)."""
from __future__ import annotations

import argparse
import os
import shutil
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "plugin", "src")
DIST = os.path.join(ROOT, "dist")


class Ref:
    n = 0

    @classmethod
    def next(cls):
        cls.n += 1
        return f"RBX{cls.n:06d}"


def cdata(text: str) -> str:
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls: str, name: str, props: str = "", children: list[str] | None = None) -> str:
    body = f'<Item class="{cls}" referent="{Ref.next()}"><Properties><string name="Name">{escape(name)}</string>{props}</Properties>'
    body += "".join(children or [])
    return body + "</Item>"


def script_item(cls: str, name: str, path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    return item(cls, name, f'<ProtectedString name="Source">{cdata(src)}</ProtectedString>')


def folder_items(directory: str, skip: set[str]) -> list[str]:
    out = []
    for entry in sorted(os.listdir(directory)):
        p = os.path.join(directory, entry)
        if entry in skip or entry.startswith("."):
            continue
        if os.path.isdir(p):
            out.append(item("Folder", entry, children=folder_items(p, set())))
        elif entry.endswith(".luau") or entry.endswith(".lua"):
            name = entry.rsplit(".", 1)[0]
            if name.endswith(".server") or name.endswith(".client"):
                continue
            out.append(script_item("ModuleScript", name, p))
    return out


def notices_item() -> str:
    p = os.path.join(ROOT, "THIRD_PARTY_NOTICES.md")
    text = open(p, encoding="utf-8").read() if os.path.exists(p) else ""
    return item("StringValue", "THIRD_PARTY_NOTICES", f'<string name="Value">{escape(text)}</string>')


def document(top: str) -> str:
    return ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
            + top + "</roblox>")


def build_plugin() -> str:
    main = os.path.join(SRC, "init.server.luau")
    if not os.path.exists(main):
        sys.exit("plugin/src/init.server.luau is missing")
    children = folder_items(SRC, {"init.server.luau"}) + [notices_item()]
    with open(main, "r", encoding="utf-8") as f:
        src = f.read()
    top = item("Script", "ClipForge", f'<ProtectedString name="Source">{cdata(src)}</ProtectedString>', children)
    return document(top)


def build_dev() -> str:
    return document(item("Folder", "ClipForgeDev", children=folder_items(SRC, {"init.server.luau"})))


def studio_content_dir() -> str | None:
    if sys.platform != "win32":
        return None
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Roblox\RobloxStudio") as k:
            return winreg.QueryValueEx(k, "ContentFolder")[0]
    except OSError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--install", action="store_true")
    ap.add_argument("--dev", action="store_true")
    a = ap.parse_args()
    os.makedirs(DIST, exist_ok=True)
    out = os.path.join(DIST, "ClipForge.rbxmx")
    with open(out, "w", encoding="utf-8") as f:
        f.write(build_plugin())
    print(f"built {out} ({os.path.getsize(out) // 1024} KB)")
    if a.install:
        plugins = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Plugins")
        os.makedirs(plugins, exist_ok=True)
        dst = os.path.join(plugins, "ClipForge.rbxmx")
        shutil.copyfile(out, dst)
        print(f"installed {dst} (Studio reloads local plugins automatically)")
    if a.dev:
        content = studio_content_dir()
        if not content:
            sys.exit("Studio content folder not found")
        d = os.path.join(content, "clipforge")
        os.makedirs(d, exist_ok=True)
        dev = os.path.join(d, "ClipForgeDev.rbxmx")
        with open(dev, "w", encoding="utf-8") as f:
            f.write(build_dev())
        print(f"dev bundle {dev} -> game:GetObjects('rbxasset://clipforge/ClipForgeDev.rbxmx')")


if __name__ == "__main__":
    main()
