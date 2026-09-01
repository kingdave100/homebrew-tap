class EquilotlCli < Formula
  desc "Cross platform CLI app for installing Equicord"
  homepage "https://github.com/Equicord/Equilotl"

  if Hardware::CPU.arm?
    url "https://github.com/Equicord/Equilotl/releases/download/v2.2.6/EquilotlCli-darwin-arm64"
    sha256 "fdd56b173760b6b1e2b548c742cbd587d53c41b1bf39b7fa28e1c90fdcc448f3"
  else
    url "https://github.com/Equicord/Equilotl/releases/download/v2.2.6/EquilotlCli-darwin-x64"
    sha256 "f1efaa5bc71e6e7a20d23ea1239df4769759820e7eedbd70ad91ead6f19c9c9b"
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
end
