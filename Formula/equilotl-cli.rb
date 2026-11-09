class EquilotlCli < Formula
  desc "Cross platform CLI app for installing Equicord"
  homepage "https://github.com/Equicord/Equilotl"

  if Hardware::CPU.arm?
    url "https://github.com/Equicord/Equilotl/releases/download/v2.3.1/EquilotlCli-arm64"
    sha256 "e098b5f9dbd57c4eb4f971d243708ddc86a8e674007c97da696829c30af0c791"
  else
    url "https://github.com/Equicord/Equilotl/releases/download/v2.3.1/EquilotlCli-x64"
    sha256 "d6099238aeb88426e85a15beaeee91fde4afbb10f679dc7f1ec76ef3fc9afe24"
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
