#!/usr/bin/env python3
"""Offline regression tests for package updates and failed upstream requests."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parents[1]
spec = importlib.util.spec_from_file_location("autobump", SCRIPTS / "autobump.py")
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class AutobumpTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for file in ("Formula/equilotl-cli.rb", "Casks/discord+equicord.rb",
                     ".github/scripts/bump-equilotl.py"):
            target = self.root / file
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / file, target)
        self.formula = self.root / "Formula/equilotl-cli.rb"
        self.cask = self.root / "Casks/discord+equicord.rb"
        self.original_formula = self.formula.read_text()
        self.original_cask = self.cask.read_text()
        # Start from whatever the tap currently ships so autobumps don't break these.
        self.equilotl = re.search(
            r"releases/download/v([^/]+)/", self.original_formula
        )[1]
        block = updater.DISCORD_BLOCK.search(self.original_cask)
        self.discord, self.discord_sha = block[2], block[4]
        self.discord_url = "https://stable.dl2.discordapp.net/distro/app/stable/osx/universal/{}/Discord.dmg"
        self.downloads = []
        self.force = False

    def curl(self, *args):
        if args[-1].endswith("/releases/latest"):
            return json.dumps({"tag_name": "v" + self.equilotl})
        if "--head" in args:
            return self.discord_url.format(self.discord)
        self.downloads.append(args[-1])
        Path(args[args.index("--output") + 1]).write_bytes(b"discord fixture")
        return ""

    def execute(self):
        with patch.object(updater, "ROOT", self.root), \
             patch.object(updater, "curl", side_effect=self.curl), \
             patch.dict("os.environ", {"FORCE": str(self.force).lower()}):
            updater.main()

    def test_current_versions_skip_downloads(self):
        self.execute()
        self.assertEqual(self.downloads, [])
        self.assertEqual(self.formula.read_text(), self.original_formula)
        self.assertEqual(self.cask.read_text(), self.original_cask)

    def bump_version(self, version):
        major, minor, patch = updater.version_key(version)
        return f"{major}.{minor}.{patch + 1}"

    def test_discord_update_preserves_legacy_and_rest_of_cask(self):
        for url in (self.discord_url,
                    "https://dl.discordapp.net/apps/osx/{}/Discord.dmg"):
            with self.subTest(url=url):
                self.cask.write_text(self.original_cask)
                self.downloads.clear()
                self.discord_url = url
                current = updater.DISCORD_BLOCK.search(self.original_cask)[2]
                self.discord = self.bump_version(current)
                self.execute()
                digest = hashlib.sha256(b"discord fixture").hexdigest()
                expected = self.original_cask.replace(
                    f'version "{current}"', f'version "{self.discord}"'
                ).replace(self.discord_sha, digest)
                self.assertEqual(self.cask.read_text(), expected)
                self.assertEqual(self.formula.read_text(), self.original_formula)
                self.assertEqual(self.downloads, [
                    f"https://dl.discordapp.net/apps/osx/{self.discord}/Discord.dmg"
                ])

    def test_force_refreshes_both_architectures_and_discord(self):
        self.force = True
        assets = []
        def download(args, **kwargs):
            assets.append(args[-1])
            Path(args[args.index("--output") + 1]).write_bytes(args[-1].encode())
        with patch.object(subprocess, "run", side_effect=download):
            self.execute()
        self.assertEqual(len(assets), 2)
        self.assertTrue(assets[0].endswith("EquilotlCli-arm64"))
        self.assertTrue(assets[1].endswith("EquilotlCli-x64"))
        self.assertEqual(len(self.downloads), 1)
        self.assertNotEqual(self.formula.read_text(), self.original_formula)

    def test_failed_lookup_leaves_both_files_untouched(self):
        with patch.object(updater, "ROOT", self.root), \
             patch.object(updater, "curl", side_effect=subprocess.CalledProcessError(22, "curl")):
            with self.assertRaises(subprocess.CalledProcessError):
                updater.main()
        self.assertEqual(self.formula.read_text(), self.original_formula)
        self.assertEqual(self.cask.read_text(), self.original_cask)

    def test_equilotl_update_changes_both_urls_and_checksums(self):
        old, self.equilotl = self.equilotl, self.bump_version(self.equilotl)
        def download(args, **kwargs):
            Path(args[args.index("--output") + 1]).write_bytes(args[-1].encode())
        with patch.object(subprocess, "run", side_effect=download):
            self.execute()
        updated = self.formula.read_text()
        self.assertNotIn(f"/v{old}/", updated)
        for arch in ("arm64", "x64"):
            url = f"https://github.com/Equicord/Equilotl/releases/download/v{self.equilotl}/EquilotlCli-{arch}"
            self.assertIn(url, updated)
            self.assertIn(hashlib.sha256(url.encode()).hexdigest(), updated)
        self.assertEqual(self.cask.read_text(), self.original_cask)

    def test_failed_discord_download_preserves_cask(self):
        with patch.object(updater, "curl", side_effect=subprocess.CalledProcessError(22, "curl")):
            with self.assertRaises(subprocess.CalledProcessError):
                updater.bump_discord(self.bump_version(self.discord), self.cask)
        self.assertEqual(self.cask.read_text(), self.original_cask)

    def test_failed_second_equilotl_download_preserves_formula(self):
        bump = __import__("runpy").run_path(str(SCRIPTS / "bump-equilotl.py"))["bump"]
        def download(args, **kwargs):
            if args[-1].endswith("-x64"):
                raise subprocess.CalledProcessError(22, "curl")
            Path(args[args.index("--output") + 1]).write_bytes(b"arm fixture")
        with patch.object(subprocess, "run", side_effect=download):
            with self.assertRaises(subprocess.CalledProcessError):
                bump(self.bump_version(self.equilotl), self.formula)
        self.assertEqual(self.formula.read_text(), self.original_formula)

    def test_invalid_and_older_versions_are_rejected(self):
        major, minor, patch = updater.version_key(self.discord)
        for version in ("garbage", f"{major}.{minor}.{patch - 1}"):
            with self.subTest(version=version):
                self.discord = version
                with self.assertRaises(ValueError):
                    self.execute()
                self.assertEqual(self.downloads, [])
                self.assertEqual(self.cask.read_text(), self.original_cask)

    def test_malformed_cask_is_not_modified(self):
        self.cask.write_text(self.original_cask.replace("on_monterey", "on_ventura"))
        original = self.cask.read_text()
        with self.assertRaises(ValueError):
            updater.bump_discord(self.bump_version(self.discord), self.cask)
        self.assertEqual(self.cask.read_text(), original)
        self.assertEqual(self.downloads, [])


if __name__ == "__main__":
    unittest.main()
