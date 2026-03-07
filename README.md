<div align="center">

# MediaClip

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A modern clipboard manager for macOS — text, images & videos.

Built as a [Clipy](https://clipy-app.com/) alternative with media support.

</div>

---

## Features

- **Clipboard History** — Automatically saves text, images (screenshots), and videos (screen recordings)
- **Smart Categories** — Separate views for text and image history
- **Snippet Manager** — Organize frequently used text with folders
- **Global Shortcut** — Access anywhere with `Cmd+Shift+V`
- **Auto Paste** — Select an item and it pastes instantly into the active app
- **Image Thumbnails** — Preview images directly in the menu
- **Customizable** — History size, display format, excluded apps, and more

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
git clone https://github.com/mata-ken/MediaClip.git
cd MediaClip
bash build.sh
open build/MediaClip.app
```

## Usage

| Action | How |
|--------|-----|
| Open menu | Click the **menu bar icon** |
| Quick access | Press `Cmd+Shift+V` anywhere |
| Paste an item | Click any history item → auto-pastes |
| Edit snippets | Menu → `Edit Snippets...` |
| Settings | Menu → `Preferences...` |

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 5.9 |
| UI Framework | SwiftUI + AppKit |
| Architecture | Menu bar app (LSUIElement) |
| Package Manager | Swift Package Manager |
| Clipboard | NSPasteboard + CGEvent |
| Storage | JSON file-based persistence |

## License

[MIT License](LICENSE)
