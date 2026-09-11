cask "discord+equicord" do
  on_big_sur do
    version "0.0.402"
    sha256 "568293a1f65fab2244b5acdac282b88b6f00efd87defd76cc77185d1b9caba64"

    livecheck do
      skip "Legacy version"
    end
  end
  on_monterey :or_newer do
    version "0.0.411"
    sha256 "d24a9e295f4b6d927e21b0c407f9bd57d2ce91efa73da7c6e2b2cc6f79d06b7d"

    livecheck do
      url "https://discord.com/api/download/stable?platform=osx"
      strategy :header_match
    end
  end

  url "https://dl.discordapp.net/apps/osx/#{version}/Discord.dmg"
  name "Discord + Equicord"
  desc "Discord with Equicord and OpenAsar preinstalled"
  homepage "https://discord.com/"

  conflicts_with cask: "discord"
  depends_on formula: "equilotl-cli"
  depends_on :macos

  # `equilotl` patches the app bundle in place and writes Equicord's data and
  # Discord's settings into the user's home. Homebrew sandboxes install steps:
  # they cannot use LaunchServices or Apple Events and cannot reach the user's
  # home directory. `installer script` is unsandboxed by design, so the vendor
  # patcher and the settings write run there.
  #
  # `installer` artifacts run before `app` moves the bundle into /Applications,
  # and the patch is path independent, so the staged bundle is patched and the
  # `app` stanza then installs the already-patched app.
  app "Discord.app"
  installer script: {
    executable: "/usr/bin/xattr",
    args:       ["-dr", "com.apple.quarantine", "#{staged_path}/Discord.app"],
  }
  installer script: {
    executable: "#{formula_opt_bin("equilotl-cli")}/equilotl",
    args:       ["-install-openasar", "-location", "#{staged_path}/Discord.app"],
  }
  installer script: {
    executable: "#{formula_opt_bin("equilotl-cli")}/equilotl",
    args:       ["-install", "-location", "#{staged_path}/Discord.app"],
  }
  installer script: {
    executable: "/usr/bin/python3",
    args:       ["-c", <<~PYTHON],
      import json, os
      path = os.path.expanduser("~/Library/Application Support/discord/settings.json")
      if os.path.exists(path):
          with open(path) as f:
              settings = json.load(f)
      else:
          os.makedirs(os.path.dirname(path), exist_ok=True)
          settings = {}

      settings["SKIP_HOST_UPDATE"] = True

      with open(path, "w") as f:
          json.dump(settings, f, indent=2)
    PYTHON
  }

  uninstall launchctl: "com.discord.discord.ShipIt",
            quit:      [
              "com.hnc.Discord",
              "com.hnc.Discord.helper.Plugin",
              "com.hnc.Discord.helper.Renderer",
            ]

  zap trash: [
    "~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.hnc.discord.sfl*",
    "~/Library/Application Support/discord",
    "~/Library/Application%20Support/discord",
    "~/Library/Caches/com.hnc.Discord",
    "~/Library/Caches/com.hnc.Discord.ShipIt",
    "~/Library/Cookies/com.hnc.Discord.binarycookies",
    "~/Library/HTTPStorages/com.hnc.Discord",
    "~/Library/HTTPStorages/com.hnc.Discord.binarycookies",
    "~/Library/Preferences/com.hnc.Discord.helper.plist",
    "~/Library/Preferences/com.hnc.Discord.plist",
    "~/Library/Saved Application State/com.hnc.Discord.savedState",
  ]
end
