# Third-Party Notices

macMender ships no third-party source code, libraries, or assets. It has no package dependencies.

It is built on Apple's system frameworks (SwiftUI, AppKit, ApplicationServices, ScreenCaptureKit, IOKit) and uses SF Symbols for its icons, under the terms of the Apple SDK. Some features call private macOS interfaces; those are described in [docs/UPGRADE.md](docs/UPGRADE.md).

Dock previews and the window switcher were written independently for this project. Other utilities were studied for what they do, and are credited as references in [docs/UPGRADE.md](docs/UPGRADE.md), but no code was copied from them.
