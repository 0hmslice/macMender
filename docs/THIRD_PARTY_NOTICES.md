# Third-Party Notices

## Ice for macOS

macMender's menu bar management is based on implementation research and adapted code patterns from Ice for macOS.

- Project: https://github.com/jordanbaird/Ice
- License: GNU General Public License v3.0
- Upstream revision referenced during this port: `11edd39115f3f43a83ae114b5348df6a0e1741cf`

Adapted concepts and code paths include:

- Stable menu bar section control identifiers (`macMender.ControlItem.Visible`, `macMender.ControlItem.Hidden`, `macMender.ControlItem.AlwaysHidden`)
- Status-item section boundaries for Visible, Hidden, and Always Hidden items
- Private WindowServer menu bar window lookup
- Targeted menu bar item event synthesis
- Event tap "scromble" routing for more reliable menu bar movement
- Frame-change verification after movement events

The project now includes GPL-3.0 licensing so these Ice-derived pieces can be shared in a license-compatible open-source release.

## Thaw

Thaw was reviewed as an actively maintained Ice fork for newer-macOS structure and stability considerations.

- Project: https://github.com/stonerl/Thaw
- Upstream revision referenced during this port: `2a8301cda7fdfbabe3723442036b293b8a490504`

Adapted concepts and code paths include:

- Source-PID resolution for Control Center-hosted status-item windows
- Stable `MenuBarItemTag` identity with `namespace:title[:instanceIndex]` persistence
- Thaw `ItemCache` insertion semantics for Visible, Hidden, and Always Hidden sections
- Fallback control item matching by source PID/title/window identity
- Hidden-section destination semantics around the Always Hidden divider
- Spacer sizing behavior for ultra-wide displays
- Screen Recording-gated live layout semantics: layout UI state is based on physical menu-bar item windows and section boundaries, not stale saved preferences

The direct-port target lives in `Sources/MacMenderMenuBarEngine/Upstream/ThawPort`. macMender exposes the Thaw-port menu-bar path as its only supported menu-bar engine.

The remaining production port is expected to vendor or adapt Thaw's coherent runtime group together: `MenuBarItemManager`, `MenuBarItemImageCache`, `LayoutBar*`, `HIDEventManager`, `ControlItem`, `IceBar`, `WindowInfo`, `Bridging`, `ScreenCapture`, and the `MenuBarItemService` XPC helper. Any copied source must keep original GPL headers and Ice/Thaw attribution.
