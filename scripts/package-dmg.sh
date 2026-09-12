#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="0.2.1"
mkdir -p build/distribution
stage=$(mktemp -d "$PWD/build/distribution/stage.XXXXXX")
# No user preferences, saved scans or files are included in this staging folder.
ditto build/Warden/Build/Products/Release/StorageWarden.app "$stage/StorageWarden.app"
ln -s /Applications "$stage/Applications"
cp docs/INSTALL.txt "$stage/START HERE.txt"
cp PRIVACY.md "$stage/PRIVACY.txt"
cp LICENSE "$stage/LICENSE.txt"
hdiutil create -volname "StorageWarden" -srcfolder "$stage" -format UDZO \
  "build/distribution/StorageWarden-$version-macOS.dmg"
cd build/distribution
shasum -a 256 "StorageWarden-$version-macOS.dmg" > "StorageWarden-$version-SHA256.txt"
