<p align="center">
  <img src="docs/banner.png" width="100%" alt="Sift"/>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.zh-CN.md">中文</a>
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-0.1-00B0FF?style=flat-square">
  <img alt="License" src="https://img.shields.io/badge/license-GPLv3-4EC51F?style=flat-square">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-000000?style=flat-square">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.0-FA7343?style=flat-square">
  <img alt="UI" src="https://img.shields.io/badge/UI-Liquid%20Glass-5AC8FA?style=flat-square">
</p>

---

<video src="docs/demo.mp4" width="100%" controls muted></video>

---

## 💡 The Problem

You just shot 800 photos. Now you need to **cull them** — toss the blurry duds,
flag the promising ones — before anything serious like editing.

- macOS **Preview can't rate or tag photos** at all.
- **No lightweight, free third-party tool** lets you mark photos and filter by those marks.
- **Adobe Bridge, Lightroom**, and the like can do it — but they're either **paid**, bloated
  pro tools, or carry a steep learning curve. Overkill just to skim and trash.

So you're stuck manually eyeballing every file, with no way to carry your picks into
the rest of your workflow.

## 🎯 The Fix

Sift does **one thing well**: fast first-pass culling. Delete the duds, tag the keepers,
move on. No library, no import, no bloat.

Three buckets — not 0–5 stars — because agonizing over 3 vs 4 is exactly the friction
that slows you down:

| Rate | Saved as | For |
|:----:|:--------:|-----|
| ❤️ **Love** | ★★★★★ (5) | The keepers |
| 👍 **Good** | ★★★ (3) | Solid, maybe usable |
| ❓ **Maybe** | ★ (1) | Decide later |

The rating is written **into the file's XMP metadata**, so it follows the photo anywhere.
Sort, filter, and group by rating in **Bridge, Lightroom, Finder, or `exiftool`** on any
platform — Sift doesn't lock you in. Your picks survive into whatever you use next.

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
- **🎨 Native macOS** — Liquid Glass on Tahoe (26), adaptive material on Sonoma (14).

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

**Requirements:** macOS 14+ (Sonoma), Xcode 26, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/yanjingtui/Sift.git
cd Sift
xcodegen generate
open Sift.xcodeproj
```

Then build and run with <kbd>⌘R</kbd> in Xcode.

> Download a pre-built DMG from the [latest release](https://github.com/yanjingtui/Sift/releases/latest) — drag to Applications and you're done. Or build from source.

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
