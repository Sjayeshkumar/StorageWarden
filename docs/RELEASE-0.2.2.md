# StorageWarden 0.2.2 - security preview

Please replace the earlier 0.2.1 preview with this version.

## Security changes

- Distribution builds no longer grant debugger access. Packaging and CI refuse unsafe debugging entitlements or missing hardened runtime.
- Whole-folder and app-bundle moves are disabled so a parent selection cannot move protected contents indirectly.
- Individual files need a fresh scan identity. Changed or substituted files are refused; a detected substitution during a move triggers a non-overwriting recovery attempt.
- Moves use directory handles, reject linked paths and never silently copy across drives. If recovery is blocked by another file, the app preserves the affected item and reports its recovery location.
- Saved scans use private, descriptor-relative reads and atomic writes. Redirected directories, symbolic links and hard-linked index files are refused. Existing permissions and extended access rules are tightened.
- Old SpaceLens indexes are no longer silently re-imported.
- GitHub Actions dependencies are pinned to immutable commits, with automatic update proposals enabled.

## Installation

Download **StorageWarden-0.2.2-macOS.dmg**, open it, and drag StorageWarden onto Applications. Quit an older copy before replacing it. Requires macOS 15 or newer; Apple silicon and Intel are included.

**Still an early preview:** this build is ad-hoc signed, not Developer ID signed or Apple-notarized. macOS may block it. Do not disable Gatekeeper. See [installation instructions](https://github.com/Sjayeshkumar/StorageWarden/blob/main/docs/INSTALL.txt).

## Important cleanup changes

Rescan a folder before attempting cleanup with an older saved index. Review individual files. Whole folders, app bundles, redirected paths and cross-drive moves must be handled in Finder instead.

Files removed by StorageWarden are placed in private StorageWarden folders inside Trash. To restore a file, drag it out using Finder. Automatic Put Back is not provided. The app never empties Trash.

## Privacy

No files, scan results or activity readings are uploaded by the app. Your saved index stays on your Mac, and activity history is not saved. Browser links, backups and cloud services are separate. See the [privacy policy](https://github.com/Sjayeshkumar/StorageWarden/blob/main/PRIVACY.md).

Security safeguards reduce risk; they are not a guarantee against all vulnerabilities. Large scans still need substantial memory, and changes made while the app was quit require a rescan.
