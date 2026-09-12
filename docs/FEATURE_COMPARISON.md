# Product research and scope

Reviewed September 12, 2026. Features below are based on the linked sources, not benchmarked performance parity.

The starting comparison was [TheSweetBits' Mac cleaner roundup](https://thesweetbits.com/best-mac-cleaner-software/).

| Reference | Useful capability | StorageWarden implementation |
| --- | --- | --- |
| [DaisyDisk disk map](https://daisydiskapp.com/guide/4/en/UnderstandingSunburst/) | Navigate a visual storage hierarchy and preview files | Sunburst, treemap, branch legend, sizes, Quick Look, Finder reveal |
| [Sensei](https://cindori.com/sensei) | Menu-bar CPU/GPU/battery monitoring and storage analysis | On-demand process CPU/memory/I/O; aggregate CPU/GPU/network/battery with explicit unavailable states |
| [App Cleaner & Uninstaller](https://nektony.com/mac-app-cleaner) | Apps, related files, startup items, updates | App bundles and associated data review; own launch-at-login control. Complete uninstall and update management remain future work |
| TheSweetBits comparison | Large files, old downloads, cache review | Indexed categories and explicit per-item cleanup review |
| [Apple FSEvents](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/TechnologyOverview/TechnologyOverview.html) | Passive directory-tree change notifications | Coalesced local subtree refresh; no idle full-disk polling |

Priority order: reliable indexing and responsiveness, readable exploration, local activity insight, safe cleanup, then additional app-management features.

We deliberately do not imitate health scores, malware-protection claims without an engine, speculative RAM cleaning, or disabling system protections. Disk speed tests, SMART diagnostics, thermal sensors, fan control, verified duplicates, and updater/uninstaller parity are not claimed in this release.
