# Contributing to StorageWarden

Contributions are welcome under the MIT license.

Use the StorageWarden Xcode scheme. Keep filesystem and process work off the main actor, reuse cached metadata, and avoid polling when an OS event stream is sufficient. Keep activity sampling tied to panel visibility.

For a bug report, include macOS version, app version, and a small reproduction. Do not attach your private index, full home-folder listing, credentials, or unredacted screenshots.

For a pull request, explain the behavior changed, add meaningful tests, run the native test suite, and describe any permission or performance implications. Never classify a path as disposable based only on its name. Never add telemetry, paywalls, advertisements, automatic deletion, or privileged helpers without discussion.

UI changes should remain accessible, keyboard-friendly, and readable in light and dark appearances. Document unsupported hardware values instead of replacing missing readings with zero.
