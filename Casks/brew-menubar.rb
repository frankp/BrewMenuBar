cask "brew-menubar" do
  version "1.0"
  sha256 "393ff3c1ea5cf610f7495bc57073a0e9ddc985405de0f3a95e43ce66af47746a"

  url "https://github.com/frankp/BrewMenuBar/releases/download/v#{version}/BrewMenuBar-v#{version}.dmg"
  name "BrewMenuBar"
  desc "macOS menu bar application for managing Homebrew packages"
  homepage "https://github.com/frankp/BrewMenuBar"

  depends_on macos: ">= :monterey"

  app "BrewMenuBar.app"

  zap trash: [
    "~/Library/Preferences/com.frankp.BrewMenuBar.plist",
  ]
end
