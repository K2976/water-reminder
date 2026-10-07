#!/bin/zsh
# Builds a Release copy of Water Reminder and installs it into /Applications.
# No Xcode window needed (it uses Xcode's command-line build tool).
#
# Run from the project root:
#     ./scripts/install.sh

set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_DIR="build"
APP_NAME="Water Reminder.app"

echo "Building..."
# CODE_SIGN_IDENTITY="-" means "ad-hoc" signing: enough to run on this Mac,
# no Apple developer account or certificate required.
# ARCHS builds a universal app that runs on both Apple Silicon and Intel Macs.
xcodebuild -project water-reminder.xcodeproj \
           -scheme water-reminder \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
           ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
           build -quiet

echo "Installing to /Applications..."
# Quit any running copy (the Xcode debug build or an older install) so it gets replaced.
pkill -x water-reminder || true
rm -rf "/Applications/$APP_NAME"
cp -R "$BUILD_DIR/Build/Products/Release/water-reminder.app" "/Applications/$APP_NAME"

open "/Applications/$APP_NAME"
echo "Done. Look for the drop icon in your menu bar."
