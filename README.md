<div align="center">

# MediaClip

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A modern clipboard manager for macOS — text, images, videos, URLs, PDFs & files.

Built as a [Clipy](https://clipy-app.com/) alternative with media support, OCR search, and one-shortcut snippet capture.

</div>

---

## Features

### Clipboard History
- **Rich Type Support** — Text, rich text (formatting preserved), images, videos, URLs, PDFs, and file paths
- **OCR Search** — Text inside images is recognized on-device (Vision) and becomes searchable
- **Smart Dedup** — SHA256 content hashing; re-copied items move to the top instead of duplicating
- **Pin Items** — Modifier-click to pin; pinned items survive history clearing and size limits
- **Security First** — Ignores transient data and password-manager (Concealed type / 1Password) content
- **Screenshot Capture** — Both clipboard screenshots and saved screenshot files (optional watcher)

### Snippets
- **⚡ Quick Capture** — Select text anywhere → `Cmd+Shift+S` → pick a folder → registered. Done.
- **History Promotion** — Cmd-click any history item to turn it into a snippet
- **Folder Hotkeys** — Assign a global hotkey to any folder for instant access at the cursor
- **Clipy-Compatible XML** — Import your snippets straight from Clipy (and export back)
- **Drag & Drop** — Reorder snippets and folders; move between folders via context menu

### Access & Paste
- **Multiple Menus** — Full menu (`Cmd+Shift+V`), history-only (`Cmd+Ctrl+V`), snippets-only (`Cmd+Shift+B`)
- **Numeric Keys** — Press `1-9, 0` while the menu is open to paste instantly
- **Modifier Actions** — Shift-click pastes as plain text, Ctrl-click deletes, Option-click pins (all configurable)
- **Search Window** — Incremental search across history, OCR text, and snippets
- **Auto Paste** — Select an item and it pastes instantly into the active app
- **Image Thumbnails** — Preview images directly in the menu; color-code swatches for hex values

### Settings
- **Hotkey Recorder** — Change every shortcut from Preferences (no config-file editing)
- **Update Check** — Lightweight GitHub Releases check (no telemetry, ever)
- **Customizable** — History size, inline/folder display counts, excluded apps, and more

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (arm64)

## Installation

### Download (Recommended)

1. Download the latest `MediaClip-vX.X.X.dmg` from [Releases](../../releases)
2. Open the DMG and drag **MediaClip.app** to your Applications folder
3. Launch MediaClip from Applications
4. **First launch:** If blocked, right-click the app → select **Open**, or go to `System Settings > Privacy & Security > Open Anyway`
5. **Accessibility permission:** Grant access at `System Settings > Privacy & Security > Accessibility`

### Build from Source

```bash
git clone https://github.com/SnsCool/MediaClip.git
cd MediaClip
bash build.sh
open build/MediaClip.app
```

## Usage

| Action | How |
|--------|-----|
| Open menu | Click the **menu bar icon** or press `Cmd+Shift+V` |
| History only / Snippets only | `Cmd+Ctrl+V` / `Cmd+Shift+B` |
| **Register selected text as snippet** | Select text → `Cmd+Shift+S` → choose folder |
| Paste an item | Click any history item → auto-pastes (or press `1-9, 0`) |
| Pin / Delete / Plain paste | `Option` / `Ctrl` / `Shift` + click a history item |
| History item → snippet | `Cmd` + click a history item |
| Search | Menu → `検索...` (searches OCR text in images too) |
| Import Clipy snippets | Snippet editor → `読み込み` (Clipy XML) |
| Edit snippets | Menu → `スニペットを編集...` |
| Settings | Menu → `環境設定...` |

## Migrating from Clipy

1. In Clipy: Snippets editor → Export → save `snippets.xml`
2. In MediaClip: Snippets editor → `読み込み` → select the XML
3. Quit Clipy and remove it from Login Items — that's it

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 5.9 |
| UI Framework | SwiftUI + AppKit |
| Architecture | Menu bar app (LSUIElement) |
| Package Manager | Swift Package Manager |
| Clipboard | NSPasteboard + CGEvent |
| OCR | Vision (on-device) |
| Storage | JSON file-based persistence |

## License

[MIT License](LICENSE)
