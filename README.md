# macMender

macMender is a privacy-first macOS utility for fixing everyday desktop friction in one cohesive native app.

The current repository contains the product and engineering foundation for the app:

- [Product and Engineering Spec](docs/PRODUCT_SPEC.md)

It also now contains a working SwiftPM macOS app with:

- Menu bar extra and preferences window
- First-launch onboarding with guided permission setup
- Local JSON profile storage
- Permission center for Accessibility, Screen Recording, and launch-at-login
- Runtime input event tap for scroll direction/gain/smoothing transforms
- Middle-click emulation from event-tap triggers and private MultitouchSupport three-finger taps
- Live menu-bar item scanning with user-selected hidden icons that reveal when hovering over Mendy
- Option+Tab window switcher controller with a native preview overlay
- Dock hover preview monitor driven by the Dock accessibility tree
- Reset-to-onboarding recovery action
- Dock preference read/diff/apply service
- Privacy manifest
- Swift tests for core transformation/diff logic

## Product Positioning

macMender combines a focused set of macOS quality-of-life tools:

- Input and scrolling tuning for mice, trackpads, apps, and profiles
- Menu bar hiding with accurate status-item detection, local choices, and hover-to-reveal behavior where macOS allows safe observation
- Dock and window enhancements, including a keyboard window switcher, Dock hover previews, and configurable Dock behavior
- A simple default profile, with optional user-created profiles for separate setups

The product is explicitly privacy-forward:

- No analytics
- No tracking
- No remote APIs
- No configuration sync unless the user later opts into an explicit export/import workflow
- Human-readable local configuration files

## Platform Direction

Target macOS 26 on Apple Silicon. The app is built with Swift, SwiftUI, and AppKit interop where needed. Some replacement-grade behavior, especially three-finger middle click, uses private macOS frameworks and is intended for direct/Homebrew distribution rather than the Mac App Store.

## Distribution Note

The primary distribution path is direct download or Homebrew with Developer ID signing and notarization. A later Mac App Store edition would need a reduced feature set because the current app links against `MultitouchSupport.framework` and uses low-level event synthesis for several replacement features.

## License

macMender is GPL-3.0 licensed. Menu bar management includes implementation patterns and adapted event-routing code from [Ice for macOS](https://github.com/jordanbaird/Ice); see `docs/THIRD_PARTY_NOTICES.md`.

## Build and Run

Build:

```bash
swift build
```

Test:

```bash
swift test
```

Build and launch as a local `.app` bundle:

```bash
./script/build_and_run.sh
```

The generated app bundle is staged at `dist/macMender.app`.

Create a Homebrew-ready zip and local cask template:

```bash
./script/package_brew.sh
```

The archive, checksum, and cask template are written to `dist/release/`.

## First Launch

On first launch, macMender opens a setup flow instead of the full preferences UI. The flow opens the correct System Settings privacy panes and provides a draggable `macMender.app` tile for permission lists that require adding the app manually.

Accessibility is required before completing setup. Screen Recording remains optional and can be enabled later for live window thumbnails.
