#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Compiling Swift files..."
swiftc -o BrewMenuBar/BrewMenuBar BrewMenuBar/BrewMenuBarApp.swift BrewMenuBar/AppDelegate.swift BrewMenuBar/BrewService.swift BrewMenuBar/PreferencesView.swift BrewMenuBar/LaunchAtLogin.swift BrewMenuBar/NotificationManager.swift BrewMenuBar/StatusBarIconStyle.swift -framework SwiftUI -framework AppKit -framework UserNotifications

echo "Creating application bundle..."
# Remove old bundle if it exists
if [ -d "BrewMenuBar.app" ]; then
    echo "Removing old BrewMenuBar.app"
    rm -rf BrewMenuBar.app
fi

mkdir -p BrewMenuBar.app/Contents/MacOS
mkdir -p BrewMenuBar.app/Contents/Resources

echo "Moving executable..."
mv BrewMenuBar/BrewMenuBar BrewMenuBar.app/Contents/MacOS/

echo "Copying Info.plist..."
cp BrewMenuBar/Info.plist BrewMenuBar.app/Contents/Info.plist

echo "Copying assets..."
if [ -f "BrewMenuBar/AppIcon.icns" ]; then
    cp BrewMenuBar/AppIcon.icns BrewMenuBar.app/Contents/Resources/
else
    echo "Warning: BrewMenuBar/AppIcon.icns not found. Run create_icon.sh first."
fi

if [ -d "icon-concepts" ]; then
    cp -R icon-concepts BrewMenuBar.app/Contents/Resources/
else
    echo "Warning: icon-concepts folder not found. Custom status bar icons will not be available."
fi

echo "Signing application..."
codesign --force --deep --sign - BrewMenuBar.app

echo "Build complete! You can run the application with:"
echo "open ./BrewMenuBar.app"
