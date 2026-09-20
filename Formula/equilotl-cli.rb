class EquilotlCli < Formula
  desc "Cross platform CLI app for installing Equicord"
  homepage "https://github.com/Equicord/Equilotl"

  if Hardware::CPU.arm?
    url "https://github.com/Equicord/Equilotl/releases/download/v2.2.7/EquilotlCli-arm64"
    sha256 "19d489f19a2da4e10b0c632d3ff6f234658350ef1c238eec79f98c26fb7cef06"
  else
    url "https://github.com/Equicord/Equilotl/releases/download/v2.2.7/EquilotlCli-x64"
    sha256 "9f05d83fec37fa7dfca94c160df30cafbbc61498445746f37aaa0ecb78c94025"
  end

  livecheck do
    url :stable
    strategy :github_latest
  end

  def install
    bin.install Dir["*"].first => "equilotl"
  end

  def post_uninstall
    path = "#{Dir.home}/Library/Application Support/Equicord"
    rm_r(path) if Dir.exist?(path)
  end

  test do
    assert_match "Equilotl Cli v#{version}", shell_output("#{bin}/equilotl -version")
  end
end
