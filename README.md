<p align="center">
  <img src="docs/banner.png" width="100%" alt="Sift"/>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.zh-CN.md">中文</a>
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-0.1-00B0FF?style=flat-square">
  <img alt="License" src="https://img.shields.io/badge/license-GPLv3-4EC51F?style=flat-square">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2026%2B-000000?style=flat-square">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.0-FA7343?style=flat-square">
  <img alt="UI" src="https://img.shields.io/badge/UI-Liquid%20Glass-5AC8FA?style=flat-square">
</p>

---

<video src="docs/demo.mp4" width="100%" controls muted></video>

---

## 💡 The Problem

Every other culling tool wants you to rate photos **0–5 stars**. So you sit there
debating whether a shot is a **3 or a 4**. That friction compounds across 800 photos
from a single shoot.

## 🎯 The Fix

Sift collapses rating to **three buckets** — and nothing more:

| Rate | Saved as | For |
|:----:|:--------:|-----|
| ❤️ **Love** | ★★★★★ (5) | The keepers |
| 👍 **Good** | ★★★ (3) | Solid, maybe usable |
| ❓ **Maybe** | ★ (1) | Decide later |

No more analysis paralysis. Three keys, one decision, next photo.

And the rating is written **directly into the file's XMP metadata** — so it travels
with the photo into Lightroom, Bridge, Windows Explorer, or `exiftool`. No database,
no sidecar files, no lock-in.

---

## ✨ Features

- **📁 Browse anywhere** — SD cards, local drives, anywhere on disk. No import, no library.
- **🎯 Three-bucket rating** — Love / Good / Maybe. Zero star-count anxiety.
- **💾 Ratings in the file** — XMP metadata, readable everywhere. Cross-platform by design.
- **🔍 Multi-filter** — combine buckets with a click or ⌘-click. See exactly what you want.
- **🖱️ Trackpad-native** — pinch to zoom photos and thumbnails, two-finger pan.
- **🗃️ Batch copy** — filter down, copy the selects to a destination folder.
- **🗑️ Trash with confirmation** — reversible, with a "don't ask again" option.
- **⌨️ Keyboard-driven** — your hands never leave the keys.
- **🎨 macOS 26 Liquid Glass** — native, fast, gorgeous.

---

## ⌨️ Keyboard

| Key | Action |
|:----|--------|
| `⌘O` | Open folder |
| `1` `2` `3` | Rate: Maybe / Good / Love |
| `0` | Clear rating |
| `←` `→` | Previous / next photo |
| `Double-click` | Open photo in detail view |
| `⌘A` | Select all |
| `⌘+click` / `Shift+click` | Multi-select |
| `Drag` | Box-select |
| `Delete` | Move to Trash |
| `Esc` | Back to grid / deselect |

---

## 📦 Build from Source

**Requirements:** macOS 26+ (Tahoe), Xcode 26, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/yanjingtui/Sift.git
cd Sift
xcodegen generate
open Sift.xcodeproj
```

Then build and run with <kbd>⌘R</kbd> in Xcode.

> Pre-built binaries ship with v0.2. For now, build from source — it takes under a minute.

---

## 🗺️ Roadmap

- [x] Three-bucket rating + XMP persistence
- [x] Multi-select, multi-filter, batch copy
- [x] Trackpad zoom & pan
- [ ] RAW format support (CR3 / NEF / ARW / RAF)
- [ ] EXIF info panel (aperture, shutter, ISO, GPS map)
- [ ] SwiftData thumbnail cache for huge folders
- [ ] AI object removal (on-device, LaMa CoreML)

---

## 🤝 Contributing

Pull requests welcome. Please open an issue first to discuss major changes.

---

## 📄 License

Copyright © 2026 Sift contributors. Distributed under the **GNU General Public License v3**.
See [LICENSE](LICENSE) for the full text.
