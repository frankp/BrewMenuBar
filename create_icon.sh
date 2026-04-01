#!/bin/bash
set -e

ASSET_DIR="BrewMenuBar/Assets.xcassets/AppIcon.appiconset"

echo "Generating icon image..."
swift GenerateIcon.swift

echo "Populating AppIcon.appiconset..."

# Create various sizes directly in the asset catalog
sips -z 16 16     icon_1024.png --out "$ASSET_DIR/icon_16x16.png"
sips -z 32 32     icon_1024.png --out "$ASSET_DIR/icon_16x16@2x.png"
sips -z 32 32     icon_1024.png --out "$ASSET_DIR/icon_32x32.png"
sips -z 64 64     icon_1024.png --out "$ASSET_DIR/icon_32x32@2x.png"
sips -z 128 128   icon_1024.png --out "$ASSET_DIR/icon_128x128.png"
sips -z 256 256   icon_1024.png --out "$ASSET_DIR/icon_128x128@2x.png"
sips -z 256 256   icon_1024.png --out "$ASSET_DIR/icon_256x256.png"
sips -z 512 512   icon_1024.png --out "$ASSET_DIR/icon_256x256@2x.png"
sips -z 512 512   icon_1024.png --out "$ASSET_DIR/icon_512x512.png"
sips -z 1024 1024 icon_1024.png --out "$ASSET_DIR/icon_512x512@2x.png"

echo "Creating AppIcon.icns for manual build..."
mkdir -p AppIcon.iconset
cp "$ASSET_DIR/icon_16x16.png"       AppIcon.iconset/
cp "$ASSET_DIR/icon_16x16@2x.png"    AppIcon.iconset/
cp "$ASSET_DIR/icon_32x32.png"       AppIcon.iconset/
cp "$ASSET_DIR/icon_32x32@2x.png"    AppIcon.iconset/
cp "$ASSET_DIR/icon_128x128.png"     AppIcon.iconset/
cp "$ASSET_DIR/icon_128x128@2x.png"  AppIcon.iconset/
cp "$ASSET_DIR/icon_256x256.png"     AppIcon.iconset/
cp "$ASSET_DIR/icon_256x256@2x.png"  AppIcon.iconset/
cp "$ASSET_DIR/icon_512x512.png"     AppIcon.iconset/
cp "$ASSET_DIR/icon_512x512@2x.png"  AppIcon.iconset/

iconutil -c icns AppIcon.iconset
# Move it to a location build.sh can find (e.g., inside BrewMenuBar source folder or root)
mv AppIcon.icns BrewMenuBar/AppIcon.icns

echo "Cleaning up..."
rm icon_1024.png
rm -rf AppIcon.iconset

echo "AppIcon assets updated successfully!"
