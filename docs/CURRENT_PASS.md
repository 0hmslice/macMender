# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/runtime-switcher-menu-hide-repair`

## Implemented in This Pass

### Runtime Switcher Discovery and Activation Repair

1. `WindowCatalogService` now records a structured discovery report for each scanned app: app name, bundle ID, PID, AX window count, CG-only fallback count, included/dropped counts, per-window CG match status, and drop/include reason.
2. Option+Tab discovery now includes AX windows even when there is no strong CG match, and falls back to CG-only windows when AX is unavailable. This prevents normal non-browser app windows from disappearing from the switcher.
3. Dock & Windows > Switcher includes a diagnostics disclosure with total discovered windows, app/window details, and the last activation diagnostic.
4. Packaged-app Computer Use verification confirmed discovery of 10 windows from 9 apps, including Finder, Terminal, System Settings, Safari, Brave, Xcode, Mail, Messages, and Codex.
5. The final activation path still uses the exact highlighted/clicked `WindowSummary`. It now activates the owning app through `NSWorkspace.OpenConfiguration`, calls `activateAllWindows`, then repeats AX raise/main/focus before verifying frontmost app and focused window identity.
6. Computer Use verified mouse-click activation of a non-browser Terminal switcher card from `dist/macMender.app`.
7. Computer Use did not successfully deliver a held Option+Tab sequence to the event tap, so keyboard modifier-release verification remains manual QA.

### Menu Bar Hide Planning Repair

1. Settings > Menu Bar is now titled `Hide Menu Bar Icons` and presents a simple safe checklist instead of a layout-manager-like hidden-area workflow.
2. `Safe Hiding Setup` and Show/Tuck UI were removed from the page body. Direct hide, reorder, restore, reveal, and third-party icon movement remain disabled.
3. Detected menu-bar rows now show resolved app icons where possible through bundle/running-app lookup, with symbols only as fallback.
4. "Mark to review" remains session-only planning state and does not persist, move, hide, restore, synthesize drags, warp the cursor, or call `MenuBarItemMover`.
5. Packaged-app Computer Use inspection confirmed the simpler page, detected icon list, real icon slots, planning-only controls, and explicit disabled physical movement messaging.

### Dock Preview Linger Clarification

1. Dock Previews now labels the setting `Preview linger after leaving Dock`.
2. The setting copy now states that it controls how long previews stay visible after the pointer leaves the Dock icon or preview safe area.
3. The setting remains wired only to `WindowSwitcherService.scheduleDockPreviewDismiss()` and does not change Dock preview identity matching.
4. New/default profiles use a 1.8s linger. Existing saved profile values are preserved and clamped to 0...10 seconds.

### Previous Option+Tab Activation and Safe Hiding Update

1. Option+Tab activation now snapshots the highlighted `WindowSummary` into an explicit activation intent before the overlay is dismissed.
2. Keyboard confirm, hover-selected keyboard confirm, and mouse-click activation all use the same final activation function.
3. Mouse click activation passes the captured card/window object directly and no longer relies on re-reading mutable `selectedIndex` after click handling.
4. Window activation diagnostics now include source, selected/highlighted indexes, selected title, CG window ID, PID, bundle ID, AX match status, frontmost app/PID, focused window ID/title, and attempted steps.
5. Activation success no longer treats owning-app activation alone as enough when the selected window has a resolvable CG window ID.
6. Settings > Menu Bar previously included `Safe Hiding Setup`; this pass replaced it with simpler hide-planning guidance.
7. No synthetic cursor movement, synthetic dragging, simulated clicks, `MenuBarItemMover` changes, package changes, signing changes, entitlements changes, scrolling changes, MiddleClick changes, or Dock tuning changes were made.

### Safe Setup and Preview Timeout Update

1. Settings > Menu Bar now presents as `Hide Menu Bar Icons`, with Command-drag steps, read-only discovery, and a session-only "mark to review" checklist for manual cleanup planning.
2. The Menu Bar page no longer leads with a broken layout-manager frame. Physical hide/reorder/reveal remains disabled and the visible safety boundary states that planning does not save hidden/reorder intent.
3. Dock preview settings now include `Preview linger after leaving Dock`, stored per profile as `DockPreviewSettings.previewIdleTimeout` and applied by `WindowSwitcherService.scheduleDockPreviewDismiss()`.
4. Existing profile decoding remains compatible when `dockPreviews` or `previewIdleTimeout` is missing.
5. Dock preview identity matching, Dock hover eligibility, Option+Tab activation, WindowCatalog matching, bundle identifiers, signing, entitlements, package structure, and `MenuBarItemMover` were not changed in this update.

### Previous Dock/Menu Safety Pass

1. Dock preview display eligibility no longer uses title/name-only matching. A Dock item must resolve to a bundle identifier or process identifier, and ambiguous neighboring Dock hits are suppressed.
2. Dock preview diagnostics now log mouse location, Dock item frame/title, resolved bundle ID/PID, suppression reason, and preview show/no-window outcomes.
3. Window discovery now prefers AX window ID and CG window ID matching, then frame overlap. Title matching is only a weak tie-breaker and is not enough to assign a CG window.
4. Option+Tab mouse hover, mouse click, and keyboard selection now share the same selected index state. Mouse click commits through the same final activation path as keyboard confirm.
5. Selected-window activation now re-resolves the AX window where possible, unminimizes, raises, sets main/focused, activates the owning app, repeats focus/raise, and logs verification details.
6. Settings > Menu Bar is now a safe setup guide with Command-drag instructions and read-only discovery. Fake lanes, drag/drop, reveal toggles, reset layout, and hide/reorder controls are no longer reachable from the page body.
7. Onboarding and Privacy settings now include guided Input Monitoring setup and a visual drag-to-add panel for adding the macMender app icon to Privacy & Security lists when macOS requires it.
8. The menu bar popover is now a compact control center with accurate status chips, permission/menu-bar setup actions, and no claims about hidden icon syncing.
9. Startup diagnostics log `Bundle.main.bundleIdentifier`, bundle path, whether the process is running from a `.app`, and whether the bundled menu-bar XPC helper exists.

## Upstream DockDoor Comparison

Inspected upstream:
`/tmp/DockDoor` at `63e14c998ac78ca04f193caa2eda3df7a3c748f9`

Relevant upstream files:

- `DockDoor/Utilities/DockObserver.swift`
- `DockDoor/Utilities/DockObserver+CmdTab.swift`
- `DockDoor/Utilities/Window Management/WindowUtil.swift`
- `DockDoor/Utilities/Window Management/WindowInfo.swift`
- `DockDoor/Views/Hover Window/Shared Components/SharedPreviewWindowCoordinator.swift`
- `DockDoor/Views/Hover Window/WindowPreviewInteractionModifier.swift`

Key behavior adapted conservatively:

- Prefer Dock AX selected-item identity and validate before display.
- Suppress previews instead of relying on app-name fallbacks.
- Resolve windows through PID, bundle ID, AX window ID, CG window ID, and frame before title.
- Use a single selected-window activation path for keyboard and mouse selection.

DockDoor parity is not claimed. macMender still does not include DockDoor's full cache, observer, animation, live preview, gesture, or private front-process stack.

## Known or Unverified

1. Real menu-bar physical movement remains disabled. No direct hide/reorder/reveal path should be reachable from the UI.
2. Safe hidden-area Show/Tuck is not exposed. It stays deferred until a macMender-owned divider/spacer flow can be verified without synthetic movement.
3. Option+Tab discovery and mouse-click non-browser activation were verified against `dist/macMender.app`; Computer Use could not deliver a held Option+Tab key sequence, so keyboard-cycle and modifier-release confirm still require manual human QA.
4. The Dock preview linger setting is build/test verified and visible in the packaged app, but actual Dock-hover linger feel still requires manual desktop QA with pointer movement over the Dock.
5. Dock preview adjacent-icon correctness, browser multi-window matching, non-running Dock items, and sticky/flicker behavior still require manual desktop QA.
6. Option+Tab exact activation still requires manual comparison across duplicate/blank titled windows, minimized windows, multiple windows from one app, and keyboard confirm.
7. The `com.apple.linkd.autoShortcut` warnings appear consistent with harmless system/Xcode launch noise unless the app intentionally adopts App Intents/Shortcuts. macMender does not.
8. `Cannot index window tabs due to missing main bundle identifier` should be treated as SwiftPM/Xcode raw executable launch noise when not running the packaged `dist/macMender.app`.
9. Permissions and XPC behavior should be trusted from `dist/macMender.app`, not the raw SwiftPM executable.

## Verification Run

- `swift build` passed after each milestone.
- `swift test` passed after each milestone; final run passed 61 tests.
- `script/build_and_run.sh --verify` passed after each milestone.
- Computer Use inspection of `dist/macMender.app` confirmed switcher discovery finds non-browser apps, diagnostics show 10 windows from 9 apps, and mouse-click activation can activate the Terminal window.
- Computer Use inspection of `dist/macMender.app` confirmed the Menu Bar page now uses `Hide Menu Bar Icons`, resolved icon rows, and no exposed physical movement controls.
- Computer Use inspection of `dist/macMender.app` confirmed the Dock preview setting is labeled `Preview linger after leaving Dock` and remains in Dock Previews.

Manual launch and visual verification should follow `docs/MANUAL_QA.md` before release claims.
