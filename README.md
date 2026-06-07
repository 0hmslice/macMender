# macMender

A privacy-first macOS utility for better gestures, Dock previews, window switching, and menu bar spacing.

The app is privacy-first by design: it runs locally, stores configuration locally, and does not include analytics, tracking, remote APIs, or configuration sync.

## Current Features

- Three-Finger Tap / Middle Click using a private multitouch bridge plus local event synthesis
- Dock hover previews with local window thumbnails when Screen Recording is available
- Option+Tab window switcher with a native preview overlay
- Input and scrolling tuning for direction, gain, smoothing, devices, apps, and profiles
- Profiles for saved input, Dock, and window behavior setups
- Limited Menu Bar Spacing controls
- Config export/import with a local backup before import
- Launch at Login and Dock icon behavior controls
- First-launch onboarding with guided permission setup
- Privacy and Permissions center for Accessibility, Screen Recording, and Input Monitoring status

## What It Can Replace or Reduce

Depending on which features you use, macMender can replace or reduce the need for:

- simple middle-click utilities
- basic Dock/window preview helpers
- small input tuning utilities
- simple menu bar spacing tweaks

## Menu Bar Boundary

macMender does not include Menu Bar management.

The only current menu-bar-adjacent feature is Menu Bar Spacing. It adjusts the system spacing defaults for menu bar items and provides a reset back to system default. It does not scan, identify, hide, move, reorder, group, reveal, or manage individual menu bar icons.

Some status-item apps may need the menu bar to refresh, or the app to relaunch, before they visually pick up changed spacing.

macMender also has its own status item and popover in the macOS menu bar. That popover is only the app control center.

## Privacy

- no analytics
- no tracking
- no remote APIs
- no configuration sync
- config stays local
- window previews stay local

## Requirements

- macOS 14 or later based on `Package.swift`
- Xcode or Command Line Tools with a Swift 6-compatible toolchain
- Apple Silicon is the main development target
- `MultitouchSupport.framework` must be present for the private three-finger tap path

`Package.swift` currently declares a macOS 14 minimum so the SwiftPM build can resolve locally. The product direction is modern macOS, and some behavior is expected to be verified on current macOS releases before distribution.

## Build and Run

Build the app source:

```bash
swift build
```

Build and launch a local `.app` bundle:

```bash
./script/build_and_run.sh
```

The generated app bundle is staged at `dist/macMender.app`.

Create a local Homebrew cask template:

```bash
./script/package_brew.sh
```

The packaging script writes a zip, checksum, and cask template to `dist/release/`. Replace the template repository URL before using it for a real release.

## Permissions

macMender uses macOS permissions only for enabled local features:

- Accessibility: required for core input and window control paths
- Screen Recording: optional, used for live window thumbnails
- Input Monitoring: shown separately from the three-finger tap runtime state

Configuration is stored in the user Application Support folder. Window thumbnails are captured locally for previews and are not uploaded.

## Distribution Notes

The current app is intended for direct distribution or Homebrew-style distribution, not the Mac App Store. The active source links against the private `MultitouchSupport.framework` and uses low-level event synthesis for replacement-style input behavior.

## Known Limitations

- The current distribution path is direct download or Homebrew-style packaging.
- The app is not Mac App Store compatible in its current form.
- Some features require Accessibility, Screen Recording, or Input Monitoring permissions.
- Menu Bar Spacing may require the menu bar to refresh or some apps to relaunch before every icon reflects the new spacing.

## License

macMender is released under the MIT License.
