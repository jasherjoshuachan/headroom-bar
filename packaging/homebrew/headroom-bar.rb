# Template for the Homebrew cask in the tap repo (jasherjoshuachan/homebrew-tap, Casks/headroom-bar.rb).
# Fill version and sha256 from the release's .sha256 file. Not signed or notarized yet, so macOS asks on first open.
cask "headroom-bar" do
  version "0.1.1"
  sha256 "REPLACE_WITH_RELEASE_SHA256"

  url "https://github.com/jasherjoshuachan/headroom-bar/releases/download/v#{version}/Headroom-#{version}.zip"
  name "Headroom"
  desc "Menu bar app showing how much of your AI plans you have left"
  homepage "https://github.com/jasherjoshuachan/headroom-bar"

  depends_on macos: :sonoma

  app "Headroom.app"

  uninstall quit: "io.github.jasherjoshuachan.headroom"

  zap trash: [
    "~/.config/headroom",
    "~/.cache/headroom",
  ]
end
