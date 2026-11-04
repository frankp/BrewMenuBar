cask "brew-menubar" do
  version "1.4"
  sha256 "3154c31d915f079fc208739860e0e38c695c605e6e6aeece4917885d613de1fe"

  url "https://github.com/frankp/BrewMenuBar/releases/download/v#{version}/BrewMenuBar-v#{version}.dmg"
  name "BrewMenuBar"
  desc "macOS menu bar application for managing Homebrew packages"
  homepage "https://github.com/frankp/BrewMenuBar"

  depends_on macos: :monterey

  app "BrewMenuBar.app"

  zap trash: [
    "~/Library/Preferences/com.frankp.BrewMenuBar.plist",
  ]
end
