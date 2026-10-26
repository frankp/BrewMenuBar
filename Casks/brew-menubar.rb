cask "brew-menubar" do
  version "1.1"
  sha256 "3839811d76145bd351a80638b158224ad8d8ab5eab9d0157285ecc522ac89617"

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
