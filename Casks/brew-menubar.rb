cask "brew-menubar" do
  version "1.3"
  sha256 "335df9ef69c07a8e856f45cffe55d244b926b4dce5eea4c00fa183972fa50983"

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
