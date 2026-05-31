# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/dockdoor-preview-menu-safe-setup`

## Implemented in This Pass

### Safe Setup and Preview Timeout Update

1. Settings > Menu Bar now presents as `Safe Menu Bar Setup`, with Command-drag steps, practical cleanup guidance, read-only discovery, and a session-only "mark to review" checklist for manual cleanup planning.
2. The Menu Bar page no longer leads with a broken layout-manager frame. Physical hide/reorder/reveal remains disabled and the visible safety boundary states that planning does not save hidden/reorder intent.
3. Dock preview settings now include `Preview idle timeout`, stored per profile as `DockPreviewSettings.previewIdleTimeout` and applied by `WindowSwitcherService.scheduleDockPreviewDismiss()`.
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
2. The new Dock preview idle timeout setting is build/test verified, but its feel still requires manual desktop QA with actual Dock hover movement.
3. Dock preview adjacent-icon correctness, browser multi-window matching, non-running Dock items, and sticky/flicker behavior still require manual desktop QA.
4. Option+Tab exact activation still requires manual comparison across browser windows, non-browser apps, duplicate/blank titled windows, minimized windows, and multiple windows from one app.
5. The `com.apple.linkd.autoShortcut` warnings appear consistent with harmless system/Xcode launch noise unless the app intentionally adopts App Intents/Shortcuts. macMender does not.
6. `Cannot index window tabs due to missing main bundle identifier` should be treated as SwiftPM/Xcode raw executable launch noise when not running the packaged `dist/macMender.app`.
7. Permissions and XPC behavior should be trusted from `dist/macMender.app`, not the raw SwiftPM executable.

## Verification Run

- `swift build`
- `swift test`
- `script/build_and_run.sh --verify`

Manual launch and visual verification should follow `docs/MANUAL_QA.md` before release claims.
