# Thaw Port Implementation Map

macMender treats Thaw 1.2.0 as the menu-bar behavior reference. Thaw is installed locally at `/Applications/Thaw.app` and the inspected upstream checkout lives at `/tmp/Thaw`.

## Current Production Boundary

- `Sources/MacMenderMenuBarEngine` is the public engine boundary and holds GPL-attributed Thaw-derived tag/cache primitives.
- `Sources/macMender/Services/MenuBarScannerService.swift` remains the app facade for now, but it must behave as an adapter over the Thaw-derived engine rather than an independent source of truth.
- `Sources/macMender/Views/Sections/MenuBarManagementView.swift` renders live physical section/order from detected status-item windows. Saved `MenuBarLayout` is persistence after explicit user action, not display truth.

## Thaw Modules To Port As A Coherent Runtime

Port these together rather than piecemeal:

- `Thaw/MenuBar/MenuBarItems/MenuBarItemManager.swift`
- `Thaw/MenuBar/MenuBarItems/MenuBarItem.swift`
- `Thaw/MenuBar/MenuBarItems/MenuBarItemTag.swift`
- `Thaw/MenuBar/MenuBarItems/MenuBarItemImageCache.swift`
- `Thaw/MenuBar/MenuBarSection.swift`
- `Thaw/MenuBar/ControlItem/ControlItem.swift`
- `Thaw/MenuBar/LayoutBar/*`
- `Thaw/MenuBar/IceBar/*`
- `Thaw/Events/HIDEventManager.swift`
- `Thaw/Events/EventTap.swift`
- `Thaw/Events/EventMonitor.swift`
- `Thaw/Utilities/ScreenCapture.swift`
- `Shared/Bridging/*`
- `Shared/Utilities/WindowInfo.swift`
- `Shared/Utilities/AXHelpers.swift`
- `Shared/Services/MenuBarItemService.swift`
- `MenuBarItemService/*`

## Packaging Requirement

Thaw uses a bundled XPC service at `Thaw.app/Contents/XPCServices/MenuBarItemService.xpc` for source-PID resolution. macMender's SwiftPM package currently builds an executable app bundle but does not yet embed an XPC service. Full Thaw parity requires adding `MacMenderMenuBarItemService.xpc` to the app bundle or moving to an Xcode project/build step that can embed the service reliably.

## Hard Rules

- Keep original GPL headers on copied Ice/Thaw files.
- Keep Ice/Thaw attribution in `docs/THIRD_PARTY_NOTICES.md`.
- The layout UI must never show an item as Hidden or Always Hidden when live window state says it is physically visible.
- Direct real-menu-bar reordering changes order only. It must not silently change section membership except to resolve a visible/hidden conflict in favor of visible reality.
- Cursor warp/hide APIs are forbidden outside the scoped Thaw-style movement guard in `MenuBarItemMover`. That one path may hide the cursor and restore the original pointer position while physically moving a status item; reveal, activation, Dock/window, and app-facing UI paths must not use cursor warp/hide APIs.
