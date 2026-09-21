cask "discord+equicord" do
  on_big_sur do
    version "0.0.402"
    sha256 "568293a1f65fab2244b5acdac282b88b6f00efd87defd76cc77185d1b9caba64"

    livecheck do
      skip "Legacy version"
    end
  end
  on_monterey :or_newer do
    version "0.0.413"
    sha256 "4bd4cd81c78095f0bf866437b92c78c06ebf2671e8b2f97635fd5556efa6f25b"

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

  app_path = "#{appdir}/Discord.app"
  equilotl = "#{formula_opt_bin("equilotl-cli")}/equilotl"

  # Homebrew runs install steps in a sandbox whose `$HOME` is a scratch
  # directory and which denies LaunchServices and Apple Events. `equilotl`
  # writes Equicord's data under the real home, and the app has to be launched
  # from the path it is installed to, so the install runs in `installer script`
  # (unsandboxed). It also places the bundle itself: `installer` artifacts run
  # before the `app` artifact, and a staged bundle must not be launched.
  # `uninstall delete:` removes what this installs.
  #
  # Everything is one script because Homebrew only sorts artifacts by class, so
  # separate `installer script` steps have no defined relative order.
  #
  # `equilotl` rewrites bundled resources, which invalidates Discord's
  # signature, and macOS then refuses the bundle with
  #
  #   "Discord" is damaged and can't be opened. You should move it to the Trash.
  #
  # because a download tracked with provenance whose seal no longer validates
  # counts as damaged. Gatekeeper assesses an app on first launch, so the
  # untouched, notarised bundle is launched once before patching; the later
  # launch of the patched bundle is then allowed. Stripping quarantine alone is
  # not enough, and ad-hoc signing is worse than useless: it drops the Team
  # Identifier, and Discord's Krisp module (`IsSignedBy`) dereferences it and
  # crashes the renderer, leaving the app stuck on its "Starting..." splash.
  installer script: {
    executable: "/bin/sh",
    args:       ["-c", <<~SH],
      set -eu

      app="#{app_path}"
      equilotl="#{equilotl}"

      # Discord's own updater would replace the patched bundle.
      /usr/bin/python3 -c '
      import json, os
      path = os.path.expanduser("~/Library/Application Support/discord/settings.json")
      try:
          with open(path) as f:
              settings = json.load(f)
      except FileNotFoundError:
          os.makedirs(os.path.dirname(path), exist_ok=True)
          settings = {}
      settings["SKIP_HOST_UPDATE"] = True
      with open(path, "w") as f:
          json.dump(settings, f, indent=2)
      '

      /usr/bin/pkill -TERM -f "$app/Contents/" 2>/dev/null || true

      /bin/rm -rf "$app"
      /usr/bin/ditto "#{staged_path}/Discord.app" "$app"
      /usr/bin/xattr -dr com.apple.quarantine "$app"

      # Best effort: there is no LaunchServices session in CI or over ssh.
      if /usr/bin/open -gj -a "$app"; then
        i=0
        while [ "$i" -lt 30 ]; do
          /usr/bin/pgrep -f "$app/Contents/MacOS/Discord" >/dev/null 2>&1 && break
          i=$((i + 1))
          /bin/sleep 1
        done
        /bin/sleep 3
      fi

      /usr/bin/pkill -TERM -f "$app/Contents/" 2>/dev/null || true
      i=0
      while [ "$i" -lt 15 ]; do
        /usr/bin/pgrep -f "$app/Contents/" >/dev/null 2>&1 || break
        i=$((i + 1))
        /bin/sleep 1
      done
      /usr/bin/pkill -KILL -f "$app/Contents/" 2>/dev/null || true

      "$equilotl" -install-openasar -location "$app"
      "$equilotl" -install -location "$app"
    SH
  }

  # `uninstall delete:` always escalates with sudo; the install above only ever
  # writes a bundle the user owns, so a plain `rm` is enough.
  uninstall launchctl: "com.discord.discord.ShipIt",
            quit:      [
              "com.hnc.Discord",
              "com.hnc.Discord.helper.Plugin",
              "com.hnc.Discord.helper.Renderer",
            ],
            script:    {
              executable: "/bin/rm",
              args:       ["-rf", app_path],
            }

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
