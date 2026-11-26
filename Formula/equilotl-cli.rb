class EquilotlCli < Formula
  desc "Cross platform CLI app for installing Equicord"
  homepage "https://github.com/Equicord/Equilotl"

  url "https://github.com/Equicord/Equilotl/releases/download/v2.4.1/EquilotlCli-universal"
  sha256 "0768b848c1538717aa3303c414b4f8829b12d3b89fee4ab9a0037c91fe377cd4"

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
