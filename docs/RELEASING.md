# Packaging StorageWarden

## Current download

Version 0.2.2 is an **early, ad-hoc-signed preview**, not an Apple-notarized release. The DMG includes the app, an Applications shortcut, installation instructions, privacy policy and MIT license. No saved scans or personal preferences are packaged.

## Build a DMG

Run these commands from the repository root with Xcode installed:

```sh
swift scripts/make-icon.swift
mkdir -p Sources/SpaceLens/Resources
iconutil -c icns build/StorageWarden.iconset -o Sources/SpaceLens/Resources/StorageWarden.icns
xcodebuild -project StorageWarden.xcodeproj -scheme StorageWarden \
  -configuration Release -derivedDataPath build/Warden \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- build
bash scripts/package-dmg.sh
```

The image and SHA-256 checksum are written to `build/distribution`. Packaging refuses to overwrite an existing DMG. Keep build output out of Git; attach the DMG and checksum to a GitHub release instead.

The icon is original, code-drawn artwork. The script renders each macOS icon size directly; the generated ICNS is committed so ordinary Xcode builds do not need to run the script.

## Before calling a release ready for everyone

1. Run the tests and check first launch, permissions, scans, cancellation, saved scans, background updates, cleanup review and menu-bar monitoring.
2. Measure responsiveness and memory on a representative large scan. Check Intel and Apple silicon Macs, not just one development machine.
3. Sign the app with an Apple Developer ID Application certificate and hardened runtime. Keep signing credentials out of the repository.
4. Submit the signed app to Apple's notary service, staple its approval, and package that approved app into a new DMG.
5. Sign and notarize the final DMG and staple its approval. Check installation on a clean Mac with Gatekeeper enabled.
6. Publish the download, checksum, supported systems and known limitations together.

The automated build workflow is not a substitute for these release checks. Do not claim an ad-hoc build is notarized, or tell users to disable Gatekeeper.
