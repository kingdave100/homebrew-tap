class EquilotlCli < Formula
  desc "Cross platform CLI app for installing Equicord"
  homepage "https://github.com/Equicord/Equilotl"

  url "https://github.com/Equicord/Equilotl/releases/download/v2.4.0/EquilotlCli-universal"
  sha256 "43ccd7aa2106b9c1eb3b9e25e180601aca5914661da9131d097c6149c8a18a0d"

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
