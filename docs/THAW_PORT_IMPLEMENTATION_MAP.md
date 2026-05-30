# Thaw Direct-Port Implementation Map

macMender treats Thaw as the menu-bar behavior reference. The inspected upstream checkout for this corrective pass lives at `/tmp/Thaw`.

Inspected upstream revision:
`644642bb880ddf71504b24bce897568398821dab`

## Current Production Boundary

- `Sources/MacMenderMenuBarEngine` is the public engine boundary and holds GPL-attributed Thaw-derived tag/cache primitives.
- `Sources/macMender/Services/MenuBarScannerService.swift` remains the app facade, but physical hide/reveal/reorder operations are disabled because the current implementation is not Thaw-equivalent.
- `Sources/macMender/Views/Sections/MenuBarManagementView.swift` is discovery-only for physical layout until the full Thaw runtime shape is transplanted.

## Current Decision

The current macMender menu-bar mover is architecturally different from Thaw and must not be patched further as if it were equivalent. It lacks Thaw's full `MenuBarItemManager` operation state machine, `HIDEventManager` coordination, `EventTap` pool/continuations, startup settling authority model, adaptive move/click timing, blocked-item recovery, pending relocation return destinations, and LayoutSolver/LayoutReconciler restore path.

Physical movement, hide/reveal, Always Hidden, secondary-bar return-to-visible, and Mendy status-item movement stay disabled until the runtime group below is transplanted and manually verified.

## Direct Repair Scope

Replace or bypass in this pass:

- `Sources/macMender/Services/MenuBarScannerService.swift`: keep the public adapter surface, but serialize refresh/reveal/hide/move operations around Thaw-derived runtime snapshots.
- `Sources/macMender/MenuBarManagement/MenuBarControlItemController.swift`: replace the simplified hidden-item controller with Thaw-derived section boundary behavior where practical.
- `Sources/macMender/MenuBarManagement/MenuBarItemDiscovery.swift` and `Sources/macMender/MenuBarManagement/MenuBarItemCore.swift`: refit identity and snapshots around Thaw-style window ID, owner PID, source PID, tag, and section concepts.
- `Sources/macMender/Views/Sections/MenuBarManagementView.swift`: reduce fake pending movement animation where it disagrees with physical menu-bar state.

Preserve and adapt:

- `Sources/macMender/MenuBarManagement/MenuBarItemMover.swift`: preserve the event relay and cursor guard, but use it only for scoped physical movement.
- `Sources/macMender/Services/MenuBarPrivateBridge.swift` and `Sources/macMender/Services/MacMenderIceEventTap.swift`: keep private WindowServer and event-tap bridges documented.
- `Sources/macMender/MenuBarManagement/MenuBarApplicationMenuController.swift`, `MenuBarInteractionController.swift`, `MenuBarItemSpacingApplier.swift`, and `MenuBarSourcePIDResolver.swift`: keep behind the direct runtime unless a Thaw-derived replacement supersedes a piece.
- `Sources/MacMenderMenuBarEngine`: extend Thaw-derived models and planning without changing package structure.

Isolate or defer:

- `Sources/macMender/MenuBarManagement/MenuBarSecondaryBarController.swift`: isolate if it conflicts with reliable inline reveal/hide. Full Thaw `IceBar` / `LayoutBar` behavior remains a parity gap.
- XPC helper embedding: no package, signing, entitlement, or bundle-identifier changes in this pass.

## Thaw Modules Used As Reference

These upstream modules were inspected as one coherent menu-bar runtime:

- `Thaw/MenuBar/MenuBarItems/MenuBarItemManager.swift`
- `Thaw/MenuBar/MenuBarItems/MenuBarItem.swift`
- `Thaw/MenuBar/MenuBarItems/MenuBarItemTag.swift`
- `Thaw/MenuBar/MenuBarItems/MenuBarItemImageCache.swift`
- `Thaw/MenuBar/MenuBarItems/LayoutSolver.swift`
- `Thaw/MenuBar/MenuBarItems/LayoutReconciler.swift`
- `Thaw/MenuBar/MenuBarItems/PendingLedger.swift`
- `Thaw/MenuBar/MenuBarItems/MenuBarItemServiceConnection.swift`
- `Thaw/MenuBar/MenuBarSection.swift`
- `Thaw/MenuBar/ControlItem/ControlItem.swift`
- `Thaw/MenuBar/ControlItem/ControlItemImage.swift`
- `Thaw/MenuBar/ControlItem/ControlItemImageSet.swift`
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

Thaw uses a bundled XPC service at `Thaw.app/Contents/XPCServices/MenuBarItemService.xpc` for source-PID resolution. macMender's `script/build_and_run.sh` can embed `MacMenderMenuBarItemService.xpc`, but the current boundary is a custom `NSXPCConnection` protocol plus an in-process fallback, not Thaw's exact `XPC` request/response service. Full Thaw parity requires matching the helper/service behavior and validating helper launch/connect/source-PID behavior side by side with Thaw.

## Hard Rules

- Keep original GPL headers on copied Ice/Thaw files.
- Keep Ice/Thaw attribution in `docs/THIRD_PARTY_NOTICES.md`.
- The layout UI must never show an item as Hidden or Always Hidden when live window state says it is physically visible.
- Direct real-menu-bar reordering is disabled until the real Thaw runtime is present.
- Cursor warp/hide APIs are forbidden outside the scoped Thaw-style movement guard in `MenuBarItemMover`. That one path may hide the cursor and restore the original pointer position while physically moving a status item; reveal, activation, Dock/window, and app-facing UI paths must not use cursor warp/hide APIs.
