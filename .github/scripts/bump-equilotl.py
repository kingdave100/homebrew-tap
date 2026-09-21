#!/usr/bin/env python3
"""Update both Equilotl binaries; brew bump-formula-pr cannot edit conditional URLs."""

import hashlib
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def bump(version, formula):
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[.-][A-Za-z0-9.-]+)?", version):
        raise ValueError(f"Invalid Equilotl version: {version!r}")

    original = formula.read_text()
    updated = original
    with tempfile.TemporaryDirectory() as directory:
        for arch in ("arm64", "x64"):
            pattern = re.compile(
                r'(url ")https://github\.com/Equicord/Equilotl/releases/download/'
                r'v[^/"\s]+/EquilotlCli-' + arch
                + r'("\s+sha256 ")[0-9a-f]{64}(")'
            )
            if len(pattern.findall(original)) != 1:
                raise ValueError(f"Expected one URL/checksum pair for {arch}")
            url = (
                "https://github.com/Equicord/Equilotl/releases/download/"
                f"v{version}/EquilotlCli-{arch}"
            )
            asset = Path(directory) / arch
            subprocess.run(
                ["curl", "--fail", "--location", "--silent", "--show-error",
                 "--retry", "3", "--connect-timeout", "10", "--max-time", "120",
                 "--output", str(asset), url],
                check=True,
            )
            digest = hashlib.sha256(asset.read_bytes()).hexdigest()
            updated = pattern.sub(
                lambda match: match[1] + url + match[2] + digest + match[3],
                updated,
            )

    # Leave the formula untouched if either download or validation fails.
    formula.write_text(updated)


if __name__ == "__main__":
    bump(sys.argv[1], Path(__file__).resolve().parents[2] / "Formula/equilotl-cli.rb")
