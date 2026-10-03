#!/usr/bin/env python3
"""Update the tap's upstream packages without Homebrew or a macOS runner."""

import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
DISCORD_BLOCK = re.compile(
    r'(  on_monterey :or_newer do\n    version ")([^"\n]+)'
    r'("\n    sha256 ")([0-9a-f]{64})(")'
)


def curl(*args):
    # Bound requests and retry transient HTTP/network errors on the Linux runner.
    return subprocess.check_output(
        ["curl", "--fail", "--location", "--silent", "--show-error",
         "--retry", "2", "--retry-all-errors", "--retry-delay", "2",
         "--connect-timeout", "10", "--max-time", "120", *args],
        text=True,
    ).strip()


def version_key(version):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError(f"Invalid upstream version: {version!r}")
    return tuple(map(int, version.split(".")))


def should_update(current, latest, force):
    old, new = version_key(current), version_key(latest)
    if new < old:
        raise ValueError(f"Refusing downgrade from {current} to {latest}")
    return new > old or force


def bump_discord(version, cask):
    version_key(version)
    original = cask.read_text()
    if len(DISCORD_BLOCK.findall(original)) != 1:
        raise ValueError("Expected one modern Discord version/checksum block")
    with tempfile.TemporaryDirectory() as directory:
        asset = Path(directory) / "Discord.dmg"
        curl("--output", str(asset),
             f"https://dl.discordapp.net/apps/osx/{version}/Discord.dmg")
        # Stream the large DMG rather than keeping it in memory.
        digest = hashlib.sha256()
        with asset.open("rb") as download:
            for chunk in iter(lambda: download.read(1024 * 1024), b""):
                digest.update(chunk)
    updated = DISCORD_BLOCK.sub(
        lambda m: m[1] + version + m[3] + digest.hexdigest() + m[5], original
    )
    # Preserve the legacy Big Sur release and every other part of the cask.
    cask.write_text(updated)


def main():
    formula = ROOT / "Formula/equilotl-cli.rb"
    cask = ROOT / "Casks/discord+equicord.rb"
    equilotl_versions = re.findall(
        r'Equilotl/releases/download/v([^/]+)/EquilotlCli-(?:arm64|x64)',
        formula.read_text(),
    )
    if len(equilotl_versions) != 2 or len(set(equilotl_versions)) != 1:
        raise ValueError("Expected matching Equilotl versions for both architectures")
    blocks = list(DISCORD_BLOCK.finditer(cask.read_text()))
    if len(blocks) != 1:
        raise ValueError("Expected one modern Discord version/checksum block")

    headers = ["-H", "Accept: application/vnd.github+json"]
    if token := os.environ.get("GH_TOKEN"):
        headers += ["-H", f"Authorization: Bearer {token}"]
    release = json.loads(curl(
        *headers, "https://api.github.com/repos/Equicord/Equilotl/releases/latest"
    ))
    latest_equilotl = release["tag_name"].removeprefix("v")
    discord_url = curl(
        "--head", "--output", os.devnull, "--write-out", "%{url_effective}",
        "https://discord.com/api/download/stable?platform=osx",
    )
    match = re.fullmatch(
        r'https://(?:dl\.discordapp\.net|stable\.dl2?\.discordapp\.net)'
        r'/apps/osx/(\d+\.\d+\.\d+)/Discord\.dmg', discord_url
    )
    if not match:
        raise ValueError(f"Unrecognized Discord download URL: {discord_url!r}")
    latest_discord = match[1]
    force = os.environ.get("FORCE", "false").lower() == "true"
    # Validate both lookups before downloading or modifying either package.
    update_equilotl = should_update(equilotl_versions[0], latest_equilotl, force)
    update_discord = should_update(blocks[0][2], latest_discord, force)
    if update_equilotl:
        print(f"Updating Equilotl to {latest_equilotl}", flush=True)
        runpy.run_path(str(ROOT / ".github/scripts/bump-equilotl.py"))["bump"](
            latest_equilotl, formula
        )
    if update_discord:
        print(f"Updating Discord to {latest_discord}", flush=True)
        bump_discord(latest_discord, cask)
    if not update_equilotl and not update_discord:
        print("Both packages are current; skipping asset downloads.")


if __name__ == "__main__":
    main()
