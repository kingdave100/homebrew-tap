#!/usr/bin/env python3
"""Update the Equilotl universal binary URL and checksum in the formula."""

import hashlib
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ASSET = "EquilotlCli-universal"


def bump(version, formula):
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[.-][A-Za-z0-9.-]+)?", version):
        raise ValueError(f"Invalid Equilotl version: {version!r}")

    original = formula.read_text()
    pattern = re.compile(
        r'(url ")https://github\.com/Equicord/Equilotl/releases/download/'
        r'v[^/"\s]+/' + ASSET + r'("\s+sha256 ")[0-9a-f]{64}(")'
    )
    if len(pattern.findall(original)) != 1:
        raise ValueError("Expected one URL/checksum pair")
    url = (
        "https://github.com/Equicord/Equilotl/releases/download/"
        f"v{version}/{ASSET}"
    )
    with tempfile.TemporaryDirectory() as directory:
        asset = Path(directory) / ASSET
        subprocess.run(
            ["curl", "--fail", "--location", "--silent", "--show-error",
             # Retry 5xx/network errors for up to ~3 minutes; GitHub's
             # release CDN can 504 for a while after a new release.
             "--retry", "6", "--retry-all-errors", "--retry-delay", "10",
             "--retry-max-time", "180",
             "--connect-timeout", "10", "--max-time", "120",
             "--output", str(asset), url],
            check=True,
        )
        digest = hashlib.sha256(asset.read_bytes()).hexdigest()

    # Leave the formula untouched if the download or validation fails.
    formula.write_text(pattern.sub(
        lambda match: match[1] + url + match[2] + digest + match[3],
        original,
    ))


if __name__ == "__main__":
    bump(sys.argv[1], Path(__file__).resolve().parents[2] / "Formula/equilotl-cli.rb")
