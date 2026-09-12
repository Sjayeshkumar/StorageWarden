# Releasing StorageWarden

Owner: https://github.com/Sjayeshkumar
Proposed repository: StorageWarden

## Source release

Publish only the maintained source, tests, Xcode project, documentation, and license. The repository ignore rules exclude local build products, scan indexes, old ClearSpace sources, user-specific Xcode state, and signing material.

Use the shared StorageWarden scheme. CI builds the app and runs tests on a macOS runner. Tag releases only after native UI checks and performance measurements on a representative large scan.

## Public binaries

The build workflow uploads an ad-hoc development ZIP artifact; it does not silently publish a release. The artifact is not notarized. For public binaries:

1. Configure your Apple Developer ID Application certificate outside the source tree.
2. Build/archive Release with hardened runtime and the intended signing identity.
3. Notarize the signed ZIP using Apple's notary service and staple the approval to the app.
4. Verify the app on a clean Mac without disabling Gatekeeper.
5. Publish the notarized ZIP and checksum alongside source release notes.

Apple signing credentials are not included. Do not claim notarization or instruct users to disable Gatekeeper for a development build.

## Release checks

- First launch presents the privacy introduction and does not start an unsolicited scan.
- Relaunch restores a saved scan without beginning another full traversal.
- Scan cancellation preserves previous results.
- Background events refresh changed folders; dropped events visibly require reconciliation.
- Scan result sizes and chart proportions pass tests.
- Process sampling stops after closing the menu panel.
- No automatic file removal or network transmission occurs.
- Check light/dark mode, small windows, keyboard navigation, external-drive removal, and permission failures.
