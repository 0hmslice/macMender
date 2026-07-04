# macMender

macMender is a privacy-first macOS utility for better input, Dock window previews, Option+Tab window switching, and menu bar spacing. It runs locally, stores configuration locally, and does not include analytics, tracking, remote APIs, or configuration sync.

## Features

- Three-Finger Tap / Middle Click using a private multitouch bridge plus local event synthesis
- Input and scrolling tuning for direction, gain, smoothing, devices, apps, and profiles
- External mice can use normal scrolling without changing trackpad scrolling
- Dock icons can show local window previews when you mouse over them
- Option+Tab window switcher with native preview cards
- Profiles for saved input, Dock, and window behavior setups
- Config export/import with a local backup before import
- Limited Menu Bar Spacing controls
- Launch at Login and Dock icon behavior controls
- First-launch onboarding with guided permission setup
- Privacy and Permissions center for Accessibility, Screen Recording, and Input Monitoring status

## Privacy

- no analytics
- no tracking
- no remote APIs
- no configuration sync
- config stays local
- window previews stay local

## Requirements

- macOS 14 or later, matching `Package.swift`
- Xcode or Apple Command Line Tools with a Swift 6-compatible toolchain
- Apple Silicon is the main development target
- `MultitouchSupport.framework` must be present for the private three-finger tap path

Some behavior may vary by macOS version, hardware, and permission state.

## Screenshots
<img width="980" height="732" alt="overview" src="https://github.com/user-attachments/assets/8904f50e-aaab-4f64-97e7-8b52cc0befb4" />
<img width="584" height="540" alt="popover" src="https://github.com/user-attachments/assets/f059547f-8f42-47f5-b4bc-6004d9a1e5d7" />
<img width="980" height="732" alt="advanced-config" src="https://github.com/user-attachments/assets/bb19e5ff-d4d9-402a-bbe8-08b3bf3fd518" />
<img width="980" height="732" alt="dock-windows" src="https://github.com/user-attachments/assets/e1146d04-0793-49bc-99e3-448e56bbcf71" />
<img width="639" height="423" alt="Screenshot1" src="https://github.com/user-attachments/assets/e239373c-0f6b-4587-87c5-c49d8edff74d" />
<img width="639" height="423" alt="Screenshot2" src="https://github.com/user-attachments/assets/c6eb2146-81b0-4be2-8d6a-cc7084062c08" />
<img width="980" height="732" alt="menu-bar-spacing" src="https://github.com/user-attachments/assets/64a8a777-a840-4ec2-915f-1809ae7e244c" />

## Build From Source

Building from source is a good option if you prefer not to use a downloaded unsigned `.app`. It can avoid some downloaded-app quarantine friction, but it does not remove macOS permission requirements.

### 1. Install Build Tools

Install Xcode or Apple Command Line Tools. If you are new to macOS development, this command is usually enough:

```bash
xcode-select --install
```

If full Xcode is installed, macOS may ask you to open Xcode once to finish setup and accept its license. If `swift` is missing in Terminal, install Command Line Tools first.

### 2. Clone The Repository

```bash
git clone https://github.com/0hmslice/macMender.git
cd macMender
```

### 3. Compile The Source

```bash
swift build
```

This compiles the Swift package and confirms the source can build on your Mac.

### 4. Build And Launch The App Bundle

```bash
./script/build_and_run.sh
```

This builds a local `.app` bundle, stages it at `dist/macMender.app`, and launches it.

To build and verify that the app launches, run:

```bash
./script/build_and_run.sh --verify
```

To create a local release package, provide the version explicitly:

```bash
./script/package_release.sh 0.1.4
```

This builds `dist/macMender.app` with SwiftPM's Release configuration and writes
`dist/macMender-v0.1.4.zip`.

The build script is executable in this repository. If your checkout loses executable permissions and Terminal says `permission denied`, run:

```bash
chmod +x script/build_and_run.sh
```

## Permissions

macMender uses macOS permissions only for local features you enable:

- Accessibility: used for core input handling and window control paths
- Screen Recording: optional, used for live Dock and window preview thumbnails
- Input Monitoring: shown separately from the three-finger tap runtime state

If the app does not appear in a permission list, launch it once and then check System Settings again. Building from source does not bypass these permission prompts.

## Troubleshooting

### `swift: command not found`

Install Apple Command Line Tools:

```bash
xcode-select --install
```

Then open a new Terminal window and try `swift build` again.

### Command Line Tools or Xcode setup errors

If Xcode is installed, open Xcode once and let it finish installing components. You may also need to accept the Xcode license before command-line builds work.

### `permission denied` when running the build script

Restore the executable bit:

```bash
chmod +x script/build_and_run.sh
```

Then run:

```bash
./script/build_and_run.sh
```

### The app launches but features do not work

Open macOS System Settings and grant the requested permissions. Some features need Accessibility, Screen Recording, or Input Monitoring before they can work.

### macOS blocks a downloaded unsigned app

Downloaded unsigned builds can trigger Gatekeeper warnings. Building from source can reduce downloaded-app quarantine friction, but macOS security and permission checks still apply.

### Menu Bar Spacing does not immediately update every icon

Some menu bar icons may not update immediately or may behave differently depending on macOS and the app that owns the icon.

## Known Limitations

- macMender is an early public macOS project.
- The current source is intended for direct or Homebrew-style distribution, not the Mac App Store.
- Some features depend on macOS permissions and may vary by macOS version and hardware.
- Menu Bar Spacing is not full menu bar management.
- The active source links against the private `MultitouchSupport.framework` for the three-finger tap path.

## License

macMender is released under the [MIT License](LICENSE).
