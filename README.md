# StorageWarden

**Your Mac. Your space. Your rules.**

A free, open-source native macOS storage explorer and menu-bar activity monitor.
Built with Swift 6 and SwiftUI. No subscriptions, accounts, ads, analytics, or cloud services.

StorageWarden is free for life. The code is available under the [MIT license](LICENSE).
Created by [Sjayeshkumar](https://github.com/Sjayeshkumar).

## Explore your storage

- Interactive sunburst, proportional treemap, folder breakdown, size distribution, and sortable file lists.
- Real file sizes, searchable paths, folder navigation, Quick Look, and Finder reveal.
- Largest files, old files, media categories, application bundles, and associated app data.
- Cleanup review for caches, downloads, archives, and recognized build artifacts.
- Explanations, confidence, importance, and removal consequences before moving files to Trash.
- Explicit skipped-location reporting and optional Full Disk Access.

## Scan once, keep the index

The saved index opens without starting a new scan. The first scan is your choice.
Metadata is stored locally in a compact binary property list and prepared for browsing on a worker actor.

While the app runs, Apple's FSEvents API watches indexed locations. Changed directories are grouped for a background refresh every two minutes. Changed directory entries are reconciled while unchanged subtrees reuse immutable records. Background changes are checkpointed at most every 15 minutes; manual scans and cleanup force a checkpoint. Low Power Mode and high thermal pressure postpone automatic refreshes. Dropped event notifications trigger a visible manual-rescan requirement.

Close the main window to keep the menu-bar app running. Quit to stop it. Launch at login is optional in Settings.
Changes made while the app is quit are not automatically reconciled; the last-updated time remains visible and a manual rescan refreshes the full saved view.

## Activity, when you need it

Click the shield in the menu bar to see system CPU, driver-exposed GPU activity, memory, battery, aggregate network throughput, and a ranked process list showing CPU, physical memory footprint, and disk writes. CPU, memory, and write-rate sorting are available.

The monitor samples every three seconds **only while its panel is open**. It saves no activity history. CPU percentages for a process use one core as 100%, so multithreaded processes may exceed 100%. Helper processes are listed separately. Unreadable processes are omitted. GPU support depends on the driver; per-app GPU readings are not available.

## Build and run

Requirements: macOS 15 or later, Xcode 16 or later, no third-party dependencies.

1. Open `StorageWarden.xcodeproj`.
2. Select the **StorageWarden** scheme and **My Mac**.
3. Run. The scheme uses an optimized Release build for everyday use.

```sh
xcodebuild -project StorageWarden.xcodeproj -scheme StorageWarden \
  -configuration Release -derivedDataPath build/Release build

xcodebuild -project StorageWarden.xcodeproj -scheme StorageWarden \
  -configuration Debug -derivedDataPath build/Tests test
```

The internal Swift module remains `SpaceLens` for source compatibility. The app and bundle are named StorageWarden.

## Current limitations

This is an early release, not a claim of feature parity with commercial utilities.

- Duplicate candidates match size and extension, not file contents. They are explicitly unverified.
- Application bundles can be reviewed for Trash; related data is reviewed separately. Complete app uninstall, extension removal, and app updates are not implemented.
- No malware scanning, fan control, privileged helpers, or speculative "RAM cleaning."
- APFS shared extents and hard links are not deduplicated; allocated bytes are an estimate, not promised reclaimable space.
- Background refresh rebuilds in-memory lookup tables after changed-subtree scans. Very large indexes still require substantial memory.
- A full scan is needed to reconcile changes made while the app was not running.
- Local builds are ad-hoc signed. A broadly distributed binary should be Developer ID signed and notarized; see [release notes](docs/RELEASING.md).

Read the [privacy policy](PRIVACY.md), [contributing guide](CONTRIBUTING.md), and [feature comparison](docs/FEATURE_COMPARISON.md).
