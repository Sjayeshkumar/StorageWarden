# StorageWarden privacy policy

Effective September 12, 2026.

StorageWarden collects no data for its developer and sends no data to a server.
It has no analytics SDK, telemetry, advertising, accounts, crash uploader, or automatic update service.

## Data on your own Mac

To show saved scans, the app stores file and folder names, paths, sizes, dates, classifications, skipped-location information, and app-initiated Trash history in:

`~/Library/Application Support/StorageWarden/index.plist`

The directory is restricted to the current user (0700) and the index file to that user (0600). These permissions are not a substitute for disk encryption. File contents are not stored in the index.
Preferences are stored in the macOS preferences system under `com.sjayeshkumar.storagewarden`.
Older SpaceLens scan indexes may be imported locally so an upgrade does not require rescanning.

Activity monitoring reads OS counters and process names locally while its panel is open. The samples are kept in memory only; there is no saved activity history.
Filesystem change monitoring is local. No file list, process list, or scan result is uploaded.

## Your controls

Scanning starts when you choose to scan. Full Disk Access and launch at login are optional and controlled through macOS. Background folder updates and the menu-bar icon can be disabled in Settings. Quitting the app stops monitoring and watching.

To erase local index/history, quit StorageWarden and remove its Application Support folder in Finder. The next launch has no saved index. An older SpaceLens index can be re-imported if it still exists; remove that old app's Application Support folder too if you want to erase both versions' scan history.

Moving files to Trash always requires review. Space is not necessarily freed until you independently empty macOS Trash.

## Links and voluntary sharing

Opening GitHub or another link uses your browser and that website's privacy policy. If you voluntarily submit screenshots or diagnostic material in an issue, review it first: paths and process names can be private. StorageWarden never submits them automatically.

This policy applies to the app distributed from this project, not independent third-party forks.
