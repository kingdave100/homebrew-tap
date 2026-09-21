class EquilotlCli < Formula
  desc "Cross platform CLI app for installing Equicord"
  homepage "https://github.com/Equicord/Equilotl"

  if Hardware::CPU.arm?
    url "https://github.com/Equicord/Equilotl/releases/download/v2.3.0/EquilotlCli-arm64"
    sha256 "46052d9aae63631a34d3a33035cb2b145f57b39ca00e9951f1806f1aa9bf70f8"
  else
    url "https://github.com/Equicord/Equilotl/releases/download/v2.3.0/EquilotlCli-x64"
    sha256 "011562fb1c3eeb5d2b0f1c53be924b6c44c8297a4a1923c933f8897da201239a"
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
