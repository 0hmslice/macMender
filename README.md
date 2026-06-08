# macMender

A privacy-first macOS utility for Dock previews, a better window switching experience, three finger tap as middle click, and menu bar spacing.

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

## Screenshots
<img width="980" height="732" alt="overview" src="https://github.com/user-attachments/assets/8904f50e-aaab-4f64-97e7-8b52cc0befb4" />
<img width="584" height="540" alt="popover" src="https://github.com/user-attachments/assets/f059547f-8f42-47f5-b4bc-6004d9a1e5d7" />
<img width="980" height="732" alt="advanced-config" src="https://github.com/user-attachments/assets/bb19e5ff-d4d9-402a-bbe8-08b3bf3fd518" />
<img width="980" height="732" alt="dock-windows" src="https://github.com/user-attachments/assets/e1146d04-0793-49bc-99e3-448e56bbcf71" />
<img width="639" height="423" alt="Screenshot1" src="https://github.com/user-attachments/assets/e239373c-0f6b-4587-87c5-c49d8edff74d" />
<img width="639" height="423" alt="Screenshot2" src="https://github.com/user-attachments/assets/c6eb2146-81b0-4be2-8d6a-cc7084062c08" />
<img width="980" height="732" alt="menu-bar-spacing" src="https://github.com/user-attachments/assets/64a8a777-a840-4ec2-915f-1809ae7e244c" />



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


## Permissions

macMender uses macOS permissions only for enabled local features:

- Accessibility: required for core input and window control paths
- Screen Recording: optional, used for live window thumbnails
- Input Monitoring: shown separately from the three-finger tap runtime state

Configuration is stored in the user Application Support folder. Window thumbnails are captured locally for previews and are not uploaded.

## Distribution Notes

The current app is intended for direct distribution or Homebrew-style distribution, not the Mac App Store. The active source links against the private `MultitouchSupport.framework` and uses low-level event synthesis for replacement-style input behavior.

## License

macMender is released under the MIT License.
