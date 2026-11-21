<p align="center">
  <img src="Sources/macMender/Resources/Brand/MacMenderAppIcon.png" width="112" alt="macMender icon">
</p>
<h1 align="center">macMender</h1>
<p align="center"><strong>Small improvements. A Mac that feels like yours.</strong></p>
<p align="center">
  Dock window previews · Window switching · Better scrolling · Trackpad middle click · Keep Awake
</p>
<p align="center">
  <a href="https://github.com/0hmslice/macMender/releases/latest"><img src="https://img.shields.io/github/v/release/0hmslice/macMender?label=download&color=2f6fed" alt="Latest release"></a>
  <a href="https://github.com/0hmslice/macMender/actions/workflows/ci.yml"><img src="https://github.com/0hmslice/macMender/actions/workflows/ci.yml/badge.svg" alt="macOS checks"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-black" alt="macOS 26 or newer">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT license"></a>
</p>
<p align="center">
  <a href="https://github.com/0hmslice/macMender/releases/latest"><strong>Download</strong></a> ·
  <a href="#get-started">Get started</a> ·
  <a href="#what-it-does">Features</a> ·
  <a href="#at-your-fingertips">Shortcuts</a> ·
  <a href="#build-it">Build it</a> ·
  <a href="https://github.com/0hmslice/macMender/issues">Report an issue</a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/v0.20.0/dock-preview-dark.png">
    <img src=".github/assets/v0.20.0/dock-preview-light.png" alt="A Dock preview showing four TextEdit windows, with close, minimize, and full screen buttons on the one under the pointer and Hide and Quit in the header">
  </picture>
</p>

<p align="center">Free, open source, and local. No accounts, no analytics, no subscriptions.</p>

> [!NOTE]
> **New in v0.20.0, the biggest update yet.** Rebuilt Dock previews, a redesigned settings window, new onboarding, and Control Center–style quick controls, in Apple's Liquid Glass on macOS 26 and later. [Download it](https://github.com/0hmslice/macMender/releases/tag/v0.20.0) or read [what changed](https://github.com/0hmslice/macMender/releases/tag/v0.20.0).

## What it does

| | |
| :-- | :-- |
| **[Dock previews](#dock-previews)** | Hover a Dock icon to see every window that app has open, then switch, close, peek, or arrange. |
| **[Window switcher](#window-switcher-and-scrolling)** | **⌥ Tab** between individual windows, not just apps. |
| **[Better scrolling](#window-switcher-and-scrolling)** | Smooth a wheel mouse, and scroll a mouse and a trackpad in different directions. |
| **Middle click** | Three-finger tap on the trackpad to open links in new tabs and close tabs. |
| **Keep Awake** | Stop your Mac sleeping for 15 minutes to 2 hours, or until you say so. |
| **[Quick controls](#quick-controls-and-setup)** | Turn any of it on or off from the menu bar. |

## Dock previews

Rest the pointer on a Dock icon and macMender shows that app's windows, live.

| | |
| :-- | :-- |
| **Every window** | Windows that are minimized, hidden, full screen, or on another Space appear alongside the ones in front of you. Minimized-window tiles in the Dock get a preview too. |
| **Act from the preview** | Click to bring one window forward. Use the red, yellow, and green buttons to close, minimize, or go full screen, or middle-click to close. Hide or quit the app from the header. |
| **Peek** | Rest on a preview to see that window at full size, in place, before you commit to switching. |
| **Arrange** | Right-click a preview for Left Half, Right Half, Fill Screen, Center, or Move to Next Display. |
| **Drag and drop** | Drag a file onto a Dock icon, then rest it on a preview to bring that window forward and drop into it. |
| **Keyboard** | With the pointer over a preview: arrow keys select, Return opens, **⌘ W** closes, Escape dismisses. |
| **Yours to tune** | Preview size, timing, titles, buttons, and a list of apps that should never show previews. |

<p align="center">
  <img src=".github/assets/v0.20.0/dock-previews.jpg" width="820" alt="The Dock Previews settings page: a switch, status, preview size, and timing sliders">
</p>

## Window switcher and scrolling

<table>
  <tr>
    <td width="50%" valign="top"><img src=".github/assets/v0.20.0/window-switcher.jpg" alt="Window Switcher settings with shortcut, layout, and thumbnail size"><br><strong>Switch windows, not just apps</strong><br>Hold <strong>⌥</strong> and press Tab to move through windows with thumbnails, including ones on other Spaces. Add Shift to go backwards.</td>
    <td width="50%" valign="top"><img src=".github/assets/v0.20.0/mouse-trackpad.jpg" alt="Mouse and Trackpad settings with smoothing sliders and a response preview"><br><strong>Scrolling, your way</strong><br>Give a wheel mouse the glide of a trackpad, reverse direction per device, and set exceptions for individual apps.</td>
  </tr>
</table>

## Settings that make sense

One window, one layout, and a page for each feature. The Overview shows what is running and lets you switch features on and off without hunting for them. On macOS 26 and later it uses Apple's Liquid Glass, with a frosted sidebar that shows what is behind the window.

<p align="center">
  <img src=".github/assets/v0.20.0/overview.jpg" width="820" alt="The Overview page: each feature with its status and a switch">
</p>

## Quick controls and setup

<table>
  <tr>
    <td width="42%" valign="top"><img src=".github/assets/v0.20.0/quick-controls.png" alt="The menu bar dropdown: tiles for Dock Previews, Window Switcher, Three-Finger Tap and Reverse Wheel, with Keep Awake and Pause"><br><strong>Everything one click away</strong><br>Click the menu bar icon to turn features on and off, start Keep Awake, or pause macMender.</td>
    <td width="58%" valign="top"><img src=".github/assets/v0.20.0/onboarding.jpg" alt="The setup screen for choosing which features to turn on"><br><strong>Set up in a minute</strong><br>Pick the features you want, allow access, and you are done.</td>
  </tr>
</table>

## Light on your Mac

macMender does nothing until you use it. Measured on an Apple silicon MacBook Air running macOS 27.2:

| Situation | CPU |
| :-- | --: |
| Running in the background | 0% |
| Pointer moving anywhere on screen | 0% |
| Settings window open | under 0.1% |
| A live Dock preview open | about 2% |

The app is about 5 MB and uses roughly 60 MB of memory.

## Get started

**Requirements:** Apple silicon · macOS 26 or newer.

The preview is signed with an Apple Development certificate and **is not notarized**. macOS may require explicit approval when opening it.

1. Download the ZIP from [Releases](https://github.com/0hmslice/macMender/releases/latest), unzip it, and move **macMender.app** to **Applications**.
2. Open macMender and follow onboarding. If macOS blocks the download, review **System Settings → Privacy & Security → Open Anyway**.
3. Enable the features you want. Open **Privacy** in macMender to review permissions.

macMender lives in the menu bar. Opening it again from Spotlight or Finder while it is running shows its settings.

| Permission | Why it is used |
| :-- | :-- |
| **Accessibility** | Global shortcuts, input adjustments, Dock detection, and window actions. |
| **Screen Recording — optional** | Local window thumbnails. Without it, previews and the switcher show app icons instead. |

Settings stay in `~/Library/Application Support/macMender/`. Use **Advanced → Backup** to export or import them. Three-finger tap and Dock previews rely on private macOS interfaces that may change with OS updates; previews fall back to public APIs when one is missing.

## At your fingertips

| Action | Default control |
| :-- | :-- |
| Next / previous window | **⌥ Tab** / **⌥ ⇧ Tab**; release Option to select, Escape to cancel |
| Quick controls | Click the menu bar icon; **⌘ ⇧ M** while macMender is active |
| Dock preview | Hover a Dock icon; click a window to bring it forward |
| Close from a preview | Red button, or middle-click the preview; Hide and Quit are in the preview's header |
| Arrange from a preview | Right-click a preview: Left Half, Right Half, Fill Screen, Center, Move to Next Display |
| Drop onto a window | Drag a file over a Dock icon, then rest it on a preview to bring that window forward |
| Peek at a window | Rest the pointer on a preview to see that window at full size |
| Preview keys | With the pointer over a preview: arrow keys select, Return opens, **⌘ W** closes, Escape dismisses |
| Middle click | Three-finger trackpad tap |
| Pause everything | **Pause macMender** in quick controls or in Advanced |

Keep Awake ends when stopped, when its timer expires, on sleep, when macMender is paused, or when it quits. It does not override closed-lid sleep.

## Menu bar spacing

**Limited on macOS 27.** macMender adjusts its own icon and saves spacing preferences for compatible apps. Our tests on macOS 27.0 (September 2026) and 27.2.1 (November 2026) found **no movement of Apple’s Wi-Fi, sound, battery, Control Center, or clock items**, even with the reported MenuBarAgent restart method. Other apps may need relaunch; full system-wide control is not promised.

Use **Menu Bar Spacing → Apply** to try it; **Use macOS Default** removes the overrides. Read the [dated findings and limitations](docs/UPGRADE.md#menu-bar-spacing-current-evidence) before relying on it.

## Build it

Install Xcode 26 or newer (macOS 26 SDK, Swift 6.2+), then:

```sh
git clone https://github.com/0hmslice/macMender.git
cd macMender
swift test
./script/build_and_run.sh
```

The script creates and opens `dist/build.noindex/macMender.app` (the `.noindex` folder keeps development builds out of Spotlight). For an optimized bundle without launching:

```sh
BUILD_CONFIGURATION=release ./script/build_and_run.sh --build-only
```

The package declares macOS 14 as its compilation minimum; that is not a claim of full feature testing on older systems. See the [upgrade notes](docs/UPGRADE.md) for architecture, comparison research, and validation scope.

<details>
<summary><strong>Something not working?</strong></summary>

- **Input or shortcuts:** check Accessibility permission, then quit and reopen macMender. Pause similar utilities while troubleshooting conflicting rules.
- **Missing thumbnails:** grant Screen Recording, or use the switcher without thumbnails.
- **Unexpected scrolling in one app:** add it under Mouse & Trackpad → App Exceptions and choose to scroll the way macOS does.
- **Need to undo a setup:** pause macMender immediately; restore exported settings from Advanced. Menu bar spacing has its own Use macOS Default button.
- **Reporting a bug:** include your macOS version, macMender version, and steps to reproduce. Review diagnostic exports before sharing them.

</details>

---

[MIT license](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Upgrade notes](docs/UPGRADE.md)
