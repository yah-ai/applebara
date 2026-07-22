<div align="center">

<img src="assets/icon.png" width="128" alt="Applebara">

# Applebara

**A ~18 MB app launcher for macOS.** Hit a hotkey, type two letters, launch an app. That's it.

</div>

## Why

macOS Spotlight keeps a full-content search index alive so you can launch apps with ⌘Space. On a quiet machine that's ~1 GB of resident `mds_stores` plus constant background indexing — to do a job that, if all you want is *launching apps from `/Applications`*, needs almost none of it.

Applebara does that one job. Its real (private) memory footprint is about **18 MB** — roughly **50× smaller** than the index it replaces — and it does zero background work when idle.

## What it does

- **Hotkey → search field.** Nothing shows until you type 2 letters (no clutter, no history, no telemetry).
- **Row of 4 app icons**, fuzzy-matched against `/Applications`, `/System/Applications`, and `~/Applications`.
- **↓ expands to a list of 10.** `←/→` (or `↑/↓` in the list) to move, **Enter** to launch, **Esc** to back out.
- Lives in the menu bar (🦫), no Dock icon.

## Build

```sh
./build.sh          # produces Applebara.app (ad-hoc signed, for local use)
open Applebara.app
```

Requires the Xcode command-line tools (`swiftc`, `sips`, `iconutil`). No Xcode project, no dependencies — it's a single `main.swift`.

## Install & make it your ⌘Space

1. Move `Applebara.app` to `/Applications` and add it as a Login Item.
2. Click the capybara in the menu bar → **Use ⌘Space (replaces Spotlight)**.

That's it. The toggle disables Spotlight's ⌘Space shortcut and rebinds Applebara
to it, taking effect immediately — no logout. Click it again to hand ⌘Space back
to Spotlight. The hotkey ships as **⌥Space** so it works out of the box without
colliding with anything.

Optional — once you're no longer using Spotlight, reclaim its index entirely
(~1 GB resident, plus all the background indexing):

```sh
sudo mdutil -a -i off && sudo mdutil -a -E
```

To undo: `sudo mdutil -a -i on`.

## Distribution (signed + notarized)

```sh
IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
ditto -c -k --keepParent Applebara.app Applebara.zip
xcrun notarytool submit Applebara.zip --keychain-profile "applebara-notary" --wait
xcrun stapler staple Applebara.app
```

Store notary credentials once with:
`xcrun notarytool store-credentials applebara-notary --apple-id <id> --team-id <TEAMID> --password <app-specific-password>`

## License

MIT — see [LICENSE](LICENSE).
