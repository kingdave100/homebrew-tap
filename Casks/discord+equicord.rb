cask "discord+equicord" do
  on_big_sur do
    version "0.0.402"
    sha256 "568293a1f65fab2244b5acdac282b88b6f00efd87defd76cc77185d1b9caba64"

    livecheck do
      skip "Legacy version"
    end
  end
  on_monterey :or_newer do
    version "0.0.410"
    sha256 "893ec758b3ae3fdc6f8c9bb197603d41042bff317aaa7d616f8ea64350d93b19"

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

  app "Discord.app"

  postflight_steps do
    # Evil hack to bypass Gatekeeper.
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "/Applications/Discord.app"]
    run "/usr/bin/open", args: ["-gj", "-a", "/Applications/Discord.app"]
    run "/usr/bin/osascript", args: ["-e", 'quit app "Discord"']

    # The step DSL has no `formula_opt_bin` helper; this is the path that helper
    # resolved to for the `equilotl-cli` dependency.
    run "{{HOMEBREW_PREFIX}}/opt/equilotl-cli/bin/equilotl",
        args:           ["-install-openasar", "-location", "/Applications/Discord.app"],
        network_access: true
    run "{{HOMEBREW_PREFIX}}/opt/equilotl-cli/bin/equilotl",
        args:           ["-install", "-location", "/Applications/Discord.app"],
        network_access: true

    run "/usr/bin/python3", args: ["-c", <<~PYTHON]
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
  end

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
