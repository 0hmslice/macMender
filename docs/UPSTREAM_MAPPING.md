# Upstream Mapping

## Current Active Upstream Dependencies

No active Menu Bar management upstream code is shipped in the current app.

The current app continues to use local Swift/AppKit/SwiftUI code plus the existing MultitouchSupport bridge for the MiddleClick subsystem.

## Historical Menu Bar References

Ice and Thaw research from earlier Menu Bar management work was moved to `docs/archive/menu-bar-removed-2026-06-02/`. Those notes are historical only.

Future Menu Bar work should start from a new design and verification plan instead of treating the archived code or docs as current product direction.

## macOS 27 Compatibility Research

The active Menu Bar Spacing compatibility research, measured behavior, source links, and license classifications are recorded in `docs/MACOS_27_COMPATIBILITY.md`.

No upstream source was copied for that work. GPL-licensed Ice and Thaw code was inspected only to understand behavior. The compatibility diagnostics and implementation are independent macMender code.
