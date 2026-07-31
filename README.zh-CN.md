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

<p align="center">
  <a href="https://github.com/yanjingtui/Sift/releases/latest">
    <img src="https://img.shields.io/badge/下载-Sift%20v0.1-00B0FF?style=for-the-badge" alt="下载 Sift">
  </a>
</p>
<p align="center"><sub>Universal DMG · Apple Silicon + Intel · macOS 14+<br>打开 → 拖到「应用程序」→ 完成</sub></p>

---

<video src="docs/demo.mp4" width="100%" controls muted></video>

---

## 💡 痛点

你刚拍完 800 张照片。现在要做**初步筛选**——删掉模糊的废片，挑出有潜力的——然后才进入
正式修图。

- macOS 自带的**预览（Preview）完全没有标记或评分功能**。
- 市面上**找不到轻量、免费的第三方工具**能标记照片再按标记筛选。
- **Adobe Bridge、Lightroom** 之类能做，但要么**付费**、要么太庞杂、学习成本高——只为过一遍删几张废片未免太重。

结果就是只能逐张肉眼过，挑出来的结果也没法带到后续流程里。

## 🎯 解法

Sift 只做**一件事，做好它**：快速初筛。删废片、标记保留、然后继续。不建库、不导入、不臃肿。

三个档位——不是 0–5 星——因为纠结 3 星还是 4 星本身就是拖慢你的摩擦：

| 评分 | 写入文件 | 含义 |
|:----:|:--------:|-----|
| ❤️ **棒极了** | ★★★★★ (5) | 必留 |
| 👍 **还不错** | ★★★ (3) | 稳，可能用得上 |
| ❓ **先留着** | ★ (1) | 以后再说 |

评分**直接写进文件的 XMP 元数据**，跟着照片走。在 **Bridge、Lightroom、Finder 或任何平台
的 `exiftool`** 里按评分排序、筛选、分组——Sift 不锁定你，你的标记能存活到接下来的任何流程。

---

## ✨ 功能

- **📁 任意浏览** — SD 卡、本地磁盘，任何位置。不导入、不建库。
- **🎯 三档评级** — 棒极了 / 还不错 / 先留着。彻底告别星级焦虑。
- **💾 标记跟文件走** — 写入 XMP 元数据，跨平台可读。
- **🔍 多条件筛选** — 单击或 ⌘+点击组合档位，想看什么就看什么。
- **🖱️ 触摸板原生** — 双指捏合放大照片和缩略图，双指拖动平移。
- **🗃️ 批量拷贝** — 筛选后一键拷贝精选到目标文件夹。
- **🗑️ 删至废纸篓** — 可逆操作，支持"不再提示"。
- **⌨️ 键盘驱动** — 双手不离键盘，全程高速操作。
- **🎨 原生 macOS** — Tahoe (26) 上是 Liquid Glass，Sonoma (14) 上自动降级为标准材质。
- **🌍 多语言** — 英语、简体中文、法语。跟随系统语言自动切换。

---

## ⌨️ 快捷键

| 按键 | 功能 |
|:----|------|
| `⌘O` | 打开文件夹 |
| `1` `2` `3` | 评分：先留着 / 还不错 / 棒极了 |
| `0` | 取消评分 |
| `←` `→` | 上一张 / 下一张 |
| `双击` | 打开照片详情 |
| `⌘A` | 全选 |
| `⌘+点击` / `Shift+点击` | 多选 |
| `拖拽` | 框选 |
| `Delete` | 移至废纸篓 |
| `Esc` | 返回网格 / 取消选择 |

---

## 📦 从源码构建

**环境要求：** macOS 14+ (Sonoma)、Xcode 26、[XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
git clone https://github.com/yanjingtui/Sift.git
cd Sift
xcodegen generate
open Sift.xcodeproj
```

在 Xcode 中按 <kbd>⌘R</kbd> 编译运行。

> 从 [最新发布](https://github.com/yanjingtui/Sift/releases/latest) 下载预编译 DMG——拖到「应用程序」文件夹即可。也可从源码构建。

---

## 🗺️ 路线图

- [x] 三档评级 + XMP 持久化
- [x] 多选、多条件筛选、批量拷贝
- [x] 触摸板缩放与平移
- [ ] RAW 格式支持（CR3 / NEF / ARW / RAF）
- [ ] EXIF 信息面板（光圈、快门、ISO、GPS 地图）
- [ ] SwiftData 缩略图缓存（应对超大文件夹）
- [ ] AI 智能擦除（端侧，LaMa CoreML）

---

## 🤝 贡献

欢迎提交 Pull Request。重大改动请先开 Issue 讨论。

---

## 📄 协议

Copyright © 2026 Sift contributors. 基于 **GNU General Public License v3** 开源。
完整协议见 [LICENSE](LICENSE)。
