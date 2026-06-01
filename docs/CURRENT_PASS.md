# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/ui-delight-status-polish`

## UI Delight and Status Polish Pass

### Post-QA Copy and State Cleanup

1. Normal Menu Bar setup UI now uses general product copy for disabled direct movement. User-facing setup text no longer mentions a Thaw-style runtime or runtime transplant.
2. Privacy permission cards are state-aware: granted Accessibility and Screen Recording permissions show their completed state without a primary `Request Access` button, while missing permissions keep the request action.
3. Middle Click copy is conditional. When disabled, the page describes it as currently disabled and only explains what it can do after setup.
4. Dock & Windows > Switcher now distinguishes the initial unscanned state from a completed empty scan. Before discovery runs, the status says `Ready to scan` and diagnostics say `No scan yet`.
5. The shared preferences shell background received a small seam polish pass to reduce harsh angular dark shapes without changing layout, Dock preview identity, thumbnail capture, Option+Tab activation/discovery, menu-bar movement, MiddleClick runtime behavior, or Dock tuning.

### Dock Preview Animation Settings

1. Dock preview settings now include presentation-only `Preview animation` and `Animation speed` controls.
2. `System`, `Fade`, `Scale`, `Slide Up`, `Glass Pop`, and `None` now use distinct presentation paths: opacity-only fade, visible frame scale, Dock-direction slide, one-shot glass pop highlight/overshoot, and immediate none.
3. `Animation speed` now has clearer timing separation: Snappy 0.10s, Balanced 0.22s, Smooth 0.36s.
4. The setting is persisted per profile and decoded safely for older configs.
5. The runtime animation changes only preview panel presentation and dismissal. It does not change Dock identity matching, title matching, thumbnail capture, caching, hover eligibility, or preview linger timing.
6. Reduce Motion degrades the preview animation to a simpler presentation path.
7. Packaged-app Computer Use inspection confirmed the settings are visible in Dock & Windows > Dock Previews and expose all animation styles plus Snappy/Balanced/Smooth speeds.
8. `Test Preview Animation` remains wired to the resolved Dock-preview path, but the transient preview panel did not surface as a separate Computer Use-verifiable window in this run; visual comparison of each animation style remains manual QA.

### App Shell Layout

1. Preferences now use a shared detail shell with a connected section header instead of relying on the detached window title area.
2. The sidebar uses one glass surface instead of nested sidebar glass, reducing the visible rectangle seam between sidebar and content.
3. Shared Preferences scroll content now centers within an adaptive width instead of pinning a max-width column to the left.
4. Overview, Menu Bar, Dock & Windows, Privacy, Profiles, and Advanced inherit the same header, content alignment, and window background rules.

### macMender Dock Self-Preview

1. Option+Tab discovery still excludes the current macMender process.
2. Dock preview uses a separate resolved-identity catalog path that can include the current process only for Dock preview display.
3. Self-preview filtering excludes blank, tiny, non-window, system-dialog, preview-panel, overlay, popover, and transient-style windows from display.
4. Packaged-app verification against `dist/macMender.app` confirmed hovering the macMender Dock icon showed one real `Overview` preferences window and did not recursively show preview panels, overlays, or the menu bar popover.
5. Dock preview identity rules were preserved: display still requires a resolved bundle identifier or process identifier. Title/name-only display eligibility was not reintroduced.

### Popover and Glass Polish

1. The menu bar popover is now a slim live status dashboard: small Mendy mark, app status, Accessibility, Screen Recording, Window Switcher, Dock Hover, and Menu Bar status rows, plus short Settings, Permissions, and Quit actions.
2. The popover no longer uses a tutorial layout, large Mendy hero, long Command-drag instructions, or hidden menu-bar syncing claims.
3. Settings surfaces received a light Liquid Glass tuning pass: lighter glass cards/rows, subtle layered background, overview runtime rows, and clearer Advanced implementation notes.
4. The Advanced notes now explicitly state that physical third-party menu-bar icon movement remains disabled.
5. Menu Bar setup now leads with live discovery status and a compact planning explanation; long manual setup rationale is under `Why manual setup?`.
6. Dock & Windows keeps raw preview diagnostics behind disclosure, Privacy presents permission status as calm checklist rows, and Advanced keeps dense implementation details in disclosures.

### Verification Notes

- `swift build` passed after each milestone in this pass.
- `swift test` passed after each milestone; final milestone runs passed 64 tests.
- `script/build_and_run.sh --verify` passed after packaging.
- Computer Use against `/Users/ryan/Documents/macMender/dist/macMender.app` confirmed the animation settings, speed picker, centered shell/header alignment, simplified Menu Bar page, Privacy checklist, and Advanced disclosures.
- Computer Use confirmed Option+Tab discovery still reports multiple normal apps after this UI pass: 12 windows from 11 apps in the packaged app.
- Settled idle CPU after returning to Overview and waiting several seconds sampled at 0.0% with about 87 MB resident memory. A previous 28.6% sample happened while actively interacting with Dock & Windows controls and did not persist once idle.
- Physical menu-bar movement remains disabled and was not re-enabled.
- Option+Tab activation/discovery and Dock preview identity logic were not changed in the visual polish milestones.
- `docs/qa/screenshots` was not modified.

## Performance Preview Cleanup Pass

### Idle CPU Reduction

1. Packaged-app baseline from `dist/macMender.app` showed reproducible idle CPU around 19-28% with the preferences window open, RSS around 134 MB, and a `sample` dominated by SwiftUI/AppKit layout/render (`NSHostingView.layout`, `ViewGraphRootValueUpdater.render`, and Core Animation transaction commits).
2. The active idle source was continuous SwiftUI animation/layout churn, especially small/sidebar Mendy instances using repeat-forever state motion while idle. Dock hover fallback polling and per-mouse-move diagnostics were also tightened so idle runtime does not perform unnecessary AX Dock reads or publish/log repeated diagnostics.
3. `MendyAvatarView` now limits continuous motion to active, panel-sized-or-larger Mendy surfaces and honors Reduce Motion. Sidebar/compact Mendy remains visible and state-specific without constantly driving layout.
4. `DockHoverService` fallback polling now returns immediately when no hover, pending preview, or displayed preview exists, and diagnostics are throttled.
5. Packaged-app after measurement showed idle CPU at 0-0.1% in the same `top` sampling window, RSS around 112 MB immediately after relaunch and around 170 MB after thumbnail capture/cache warmup.

### Dock Preview Thumbnail Latency

1. The previous thumbnail path called `SCShareableContent.current` once per missing thumbnail. The new path adds a batch thumbnail API that resolves `SCShareableContent.current` once per preview batch and captures thumbnails for the requested windows from that shared content snapshot.
2. `WindowSwitcherService` now orders the preview/switcher panel before thumbnail capture starts, so the UI can appear with placeholders and progressively fill thumbnails.
3. Thumbnails are cached by stable `WindowSummary.ID`, with a 20 second TTL and an 80 image bound. Expired entries are pruned before each prefetch.
4. `WindowCatalogService.visibleWindows()` now uses a short 0.35 second discovery cache to avoid repeated full AX/CG scans during immediate show/refresh paths without weakening Dock preview identity rules.
5. `Test Dock Preview` now uses the most recent discovered window's resolved bundle/PID identity. The dead title-only `showDockPreview(appName:)` path was removed.
6. Computer Use against `/Users/ryan/Documents/macMender/dist/macMender.app` verified switcher discovery still found 10 windows from 9 apps. First thumbnail batch reported `requested=10 cached=0 captured=10 duration=382ms`; repeated Test Dock Preview reported `requested=1 cached=1 captured=0 duration=0ms`.
7. Dock preview identity matching was preserved: preview display still requires a resolved bundle identifier or process identifier, and title/name matching is not a final eligibility reason.

### Verification Notes

- `swift build` passed after each milestone in this pass.
- `swift test` passed after each milestone; final run passed 62 tests.
- `script/build_and_run.sh --verify` passed after packaging.
- Computer Use initially attached to a stale cached `local.macmender.app` from `/var/folders/...`; verification was repeated by targeting `/Users/ryan/Documents/macMender/dist/macMender.app` explicitly.
- Computer Use confirmed Option+Tab discovery still reports multiple normal apps from the packaged app.
- Computer Use confirmed Dock & Windows > Dock Previews shows the thumbnail runtime diagnostic and cache hit/miss behavior.
- Menu Bar safe setup was opened previously in this branch and no menu-bar movement code was changed in this pass.

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
