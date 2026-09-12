# Security

Please report security issues privately through GitHub's vulnerability reporting feature when it is enabled for this repository. Do not publish a user's file paths, local index, personal files, or credentials in a public issue.

StorageWarden does not run as root, install privileged helpers, or bypass SIP. Cleanup uses macOS Trash and a reviewed selection. File classification is guidance, not a guarantee that data is unnecessary. Keep backups of important files.

Signed and notarized release binaries will be identified explicitly. Do not treat an unnotarized development artifact as an officially notarized release.

## Security preview 0.2.2

Use 0.2.2 or later rather than the retired 0.2.1 download. Distribution packaging checks the built app's entitlements and hardened runtime before creating a disk image. These checks do not imply Apple notarization.

Cleanup is restricted to individually reviewed regular files with a scan-time identity. Whole folders and app bundles are blocked. The filesystem operation revalidates identity, walks directory handles without following user-created links, uses an exclusive same-volume rename into a private Trash folder, and attempts a non-overwriting rollback if the moved item does not match. A failed rollback preserves the item and reports where to recover it. No app operation permanently deletes file contents.

Saved indexes reject redirected paths and linked files; reads and writes enforce current-user ownership, private permissions and empty extended ACLs. Writes use exclusively created private temporary files and descriptor-relative atomic replacement. Local index size is limited to 512 MB. Legacy indexes are not automatically imported.

These safeguards are not protection against a fully compromised user account, root access or a process that already has equivalent filesystem permissions. Keep backups. Tests use isolated temporary fixtures and never the user's real documents or Trash.
