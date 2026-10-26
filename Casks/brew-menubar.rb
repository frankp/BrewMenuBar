cask "brew-menubar" do
  version "1.2"
  sha256 "fe51c751b8c6846bcf27ed0e166f17e4783224facaefb998d1373b3e17b79c38"

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
