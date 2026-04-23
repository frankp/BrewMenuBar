#!/bin/bash

# Exit on error
set -e

VERSION=${1:-"1.0"}
APP_NAME="BrewMenuBar"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"

echo "Building ${APP_NAME}..."
./build.sh

echo "Creating DMG package..."
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

# Create a temporary folder for the DMG content
mkdir -p dist
cp -R "${APP_NAME}.app" dist/

# Create the DMG
hdiutil create -volname "${APP_NAME}" -srcfolder dist -ov -format UDZO "$DMG_NAME"

# Clean up
rm -rf dist

echo "--------------------------------------------------"
echo "Package created: $DMG_NAME"
echo "SHA256 Checksum:"
shasum -a 256 "$DMG_NAME"
echo "--------------------------------------------------"
echo "Next steps:"
echo "1. Upload $DMG_NAME to your GitHub Releases."
echo "2. Copy the public download URL."
echo "3. Update the 'url' and 'sha256' in brew-menubar.rb"
