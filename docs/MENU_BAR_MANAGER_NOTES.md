# macMender Menu Bar Manager Notes

## Upstream Basis

macMender's menu bar manager is based on implementation research from:

- Ice for macOS: https://github.com/jordanbaird/Ice, revision `11edd39115f3f43a83ae114b5348df6a0e1741cf`
- Thaw: https://github.com/stonerl/Thaw, revision `2a8301cda7fdfbabe3723442036b293b8a490504`

Ice is the primary upstream reference. macMender is GPL-3.0 licensed so adapted code paths can remain license-compatible and improvements can be shared back.

## Architecture

- Production rewrite status: the old macMender-specific scan/order model is no longer considered authoritative. The UI must render live physical section/order from the engine snapshot, and persisted `MenuBarLayout` is treated as restore/import/export state after explicit user actions. A detected item that is physically visible must not be displayed as Hidden or Always Hidden just because stale config says so.
- The intended production boundary is a GPL-attributed Thaw-derived `MacMenderMenuBarEngine` with a bundled `MacMenderMenuBarItemService` XPC helper. Thaw 1.2.0 includes this helper at `Thaw.app/Contents/XPCServices/MenuBarItemService.xpc`; macMender's SwiftPM package still needs the equivalent bundle/product wiring before the legacy in-process source-PID resolver can be removed completely.
- `MacMenderMenuBarEngine` is now a separate SwiftPM target that holds the public menu-bar engine protocol, snapshot/status models, and Thaw-derived tag/cache primitives. This is the Phase 1 landing point for the direct Thaw port.
- `MenuBarScannerService` conforms to `MenuBarEngineProtocol` as the single app-facing menu-bar engine path.
- `MenuBarScannerService` is now a facade used by the rest of the app. It owns runtime state and coordinates the smaller Ice-style components.
- `MenuBarItemDiscovery` enumerates real WindowServer menu-bar item windows through `MenuBarPrivateBridge`. It follows Thaw's live-order approach by reading the private menu-bar window list, reversing that CGS stream before creating item records, and preserving that order through normalization instead of re-sorting by stale frame heuristics. It deliberately avoids AX-only guesses so normal app windows like Finder, Messages, and browsers are not shown as hideable menu-bar icons.
- `MenuBarSourcePIDResolver` mirrors Thaw's source-PID matching for newer macOS status-item hosts. It matches WindowServer window centers against `AXExtrasMenuBar` children so Control Center-hosted windows can be attributed to the real source app when possible.
- Discovery filters to the active Space, matching Ice's `activeSpaceOnly` mode, propagates source PIDs across duplicate multi-icon app hosts when Thaw's same-title/same-owner evidence is strong enough, assigns stable instance indexes for duplicate `namespace:title` items, and collapses duplicate transient windows by keeping the best on-screen/nonzero-width candidate.
- `MenuBarSectionResolver` maps item frames into Visible, Hidden, and Always Hidden sections using stable delimiter status items named `macMender.ControlItem.Visible`, `macMender.ControlItem.Hidden`, and `macMender.ControlItem.AlwaysHidden`.
- `MenuBarControlItemController` owns the Hidden and Always Hidden delimiter status items. It expands or collapses those controls instead of repeatedly dragging unrelated visible items during reveal/hide. Normal reveal keeps the Always Hidden delimiter expanded when Always Hidden items exist, so those items are not exposed by hover, empty-area click, scroll, or secondary-bar reveal. Hidden and Always Hidden are tracked independently so an Always Hidden-only layout does not expand the ordinary Hidden divider and accidentally conceal visible items.
- `MenuBarItemMover` contains the Ice/Thaw-derived event synthesis used for one-time item arrangement. It follows Thaw's guarded movement model: hide the cursor, relay the targeted status-item move through the session event path, verify the item frame changed, then restore the cursor to its original point exactly once.
- `MenuBarInteractionController` owns local/global event monitors for hover, empty-space click, scroll/swipe, and timer ticks.
- `MenuBarApplicationMenuController` detects frontmost app menu frames through Accessibility and temporarily hides app menus when revealed status items would overlap them.
- `MenuBarSecondaryBarController` displays hidden items in a separate translucent bar. In the first macMender pass, it provides quick visibility actions and an explicit reveal-in-menu-bar control.
- `MenuBarItemSpacingApplier` writes `NSStatusItemSpacing` and `NSStatusItemSelectionPadding`, then relaunches status-item-owning apps so the visual spacing change takes effect.

## Intentional Deviations

- The Thaw-port path is the only exposed menu-bar engine. There is no user-facing backend switch and no supported fallback to the older experimental path.
- macMender keeps the app-facing API name `MenuBarScannerService` to avoid broad unrelated rewiring.
- Menu Bar Layout lanes now prefer the detected live `actualSection` over saved desired config. This is required for Thaw parity: if WindowServer shows an item in the real menu bar, macMender must not keep presenting it as Hidden in the layout UI.
- Startup reconciliation is intentionally narrow. macMender performs one delayed restore for stored concealed items after launch, but normal scans and settings changes no longer run background section reconciliation. Relaunching the app should not rebalance or reorder visible items unless the user explicitly changes sections/order.
- Cursor movement APIs are isolated to `MenuBarItemMover` and are used only as a Thaw-style guard around physical status-item movement. Other menu-bar code must not move or hide the cursor. The acceptance criterion is no visible pointer jump and stable pointer coordinates before/after repeated hide/reveal/drag operations.
- The secondary bar is implemented as a SwiftUI/AppKit panel that lists ordinary Hidden items and can move them back to Visible. Always Hidden items are excluded from normal secondary-bar reveal. Directly forwarding clicks into hidden status item menus is deferred until we can test it across third-party menu extras.
- Stats is treated as a supported multi-icon app, not a read-only system item. On macOS 26 it can resolve through the Control Center `CombinedModules` host; macMender now follows Thaw's source-PID and stable-instance approach so source-resolved Stats items can be assigned to Visible, Hidden, or Always Hidden. Full physical parity for every Stats multi-icon layout remains part of the Thaw-port validation matrix rather than an intentional limitation.
- Current smoke-test result on macOS 26: moving Stats to Hidden physically conceals the `CombinedModules` window behind the expanded `macMender.ControlItem.Hidden` divider while Wi-Fi, Sound, Battery, and other visible items remain onscreen. Menu Bar Layout now keeps a live sync loop while the panel is open, so command-drag reordering in the real menu bar is reflected back into the lanes from the same Screen Recording-gated window stream that Ice/Thaw use. Continue treating any visible lane/real-bar mismatch as a parity bug.
- True read-only handling is reserved for observed OS constraints and upstream-compatible exclusions: Clock, the Control Center/BentoBox item, transient privacy/capture modules, and unresolved generic Control Center hosts remain fixed unless source-PID matching identifies a real non-Control Center source app.
- Mendy's in-app motion is limited to short mood-change animations. Earlier repeat-forever animations kept SwiftUI rendering at roughly 28% CPU with Settings open; after the change the same idle check settled at 0.0% CPU.
- Reveal behavior is configurable in macMender's settings rather than hidden behind advanced defaults: hover, empty-space click, scroll/swipe, auto-rehide, app-menu overlap hiding, and secondary bar display can each be toggled.

## Upstream Contribution Path

If macMender improves stability or newer macOS compatibility, keep those changes isolated in `Sources/macMender/MenuBarManagement` and file them upstream against Ice or Thaw with:

- the exact macOS version tested,
- before/after WindowServer frame behavior,
- whether the change affects Intel, Apple Silicon, or both,
- and any private API assumptions.
