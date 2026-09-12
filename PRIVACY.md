# Privacy, in plain language

Effective September 12, 2026.

## The short answer

**We collect nothing from your use of StorageWarden. The app does not upload your files, scan results, or activity readings.**

There are no accounts, ads, trackers, analytics, crash-upload tools, or automatic update checks. You do not need an internet connection to scan your storage or view activity.

## What stays on your Mac?

To remember a scan, StorageWarden saves file and folder names, locations, sizes, dates, file categories, locations it could not read, and its cleanup history. It does not save copies of your file contents.

This saved list is stored here:

`~/Library/Application Support/StorageWarden/index.plist`

The folder and file have permissions limited to your Mac user account (0700 and 0600). They are not separately encrypted. Other software running with your account's access may be able to read them.

Settings are saved through macOS preferences under `com.sjayeshkumar.storagewarden`. If you used the older SpaceLens app, an old saved scan may be imported on your Mac.

Activity readings come from macOS while the activity panel is open. They stay in memory and are not saved as an activity history. Folder-change monitoring also happens locally.

## You are in control

- You choose when to start a scan and which folder to scan.
- Full Disk Access is optional. It allows more locations to be read; it does not upload them.
- Background updates and the menu-bar icon can be turned off in Settings.
- Starting at login is optional.
- Quitting the app stops monitoring and background updates.
- Files are only moved to Trash after your review. The app does not empty Trash automatically.

## Remove your saved scan

1. Quit StorageWarden.
2. In Finder, choose **Go > Go to Folder**.
3. Enter `~/Library/Application Support/StorageWarden`.
4. Move that StorageWarden folder to Trash. This removes the app's saved scan and cleanup history, not the files you scanned.

If you previously used SpaceLens, its old saved scan can be imported again. Remove the old `~/Library/Application Support/SpaceLens` folder too if you want to remove both apps' saved scans. Your preferences and macOS backups are separate.

## What about links, backups and cloud folders?

The promise above describes what **StorageWarden itself sends**: nothing from your scans or monitoring.

If you click a website link, your browser contacts that website under its privacy policy. If you post a screenshot or issue on GitHub, you choose what to share. Check for private names and file paths first; the app never submits them automatically.

Your own backup software, cloud-sync settings, and macOS services work independently of StorageWarden. For example, opening a cloud-only file may cause its provider to download it. We cannot promise that those other services never transfer data.

This policy covers the official StorageWarden project, not modified versions published by other people.
