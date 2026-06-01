# Manual QA

Use this file for verification that cannot be proven by `swift build` or `swift test`.

## Launch Method

- Use `script/build_and_run.sh --verify` or `open dist/macMender.app` for permissions, XPC, bundle identity, and menu-bar behavior testing.
- Do not trust raw SwiftPM executable or Xcode SwiftPM-run behavior for Privacy & Security identity tests.
- In packaged-app logs, confirm startup diagnostics report a non-nil bundle identifier, a `.app` bundle path, and `xpcHelperExists=true`.
- Treat repeated `com.apple.linkd.autoShortcut` warnings as harmless system/Xcode noise unless macMender later adopts App Intents or Shortcuts.
- Treat `Cannot index window tabs due to missing main bundle identifier` as raw executable/Xcode launch noise if it does not appear from `dist/macMender.app`.

## Current Pass Checklist

- Launch `dist/macMender.app` and inspect onboarding, Preferences, Menu Bar, Dock & Windows, Privacy, and Profiles.
- When using Computer Use, target `/Users/ryan/Documents/macMender/dist/macMender.app` explicitly. The generic app name can attach to stale cached bundles under `/var/folders/...`.
- Confirm packaged-app idle CPU stays near 0% after the window is idle for several seconds. Recheck with `top -l 5 -s 1 -pid $(pgrep -x macMender | head -n1)` or Activity Monitor.
- Confirm onboarding shows Accessibility, Screen Recording, and guided Input Monitoring setup.
- Confirm the drag-to-add guidance says to drag the macMender app icon if it is not listed, includes the fallback `+`/reopen instruction, and does not claim permissions are granted.
- Confirm Settings > Menu Bar looks like a safe setup guide, not a broken layout manager.
- Confirm Settings > Menu Bar title reads `Hide Menu Bar Icons`.
- Confirm Settings > Menu Bar shows Command-drag instructions, read-only discovery, session-only "Mark to review" planning controls, and clear disabled states for direct reorder/hide/reveal.
- Confirm Settings > Menu Bar does not show `Safe Hiding Setup`, `Show/Tuck Hidden Area`, layout lanes, fake hidden sections, or automatic third-party icon movement controls.
- Confirm detected menu-bar rows show resolved app icons where possible and fall back gracefully for unresolved/system items.
- Confirm "Mark to review" does not move, hide, persist, or imply any physical menu-bar operation.
- Confirm no fake drag, reorder, move-to-hidden, Always Hidden, checkbox hide, or physical movement controls are reachable.
- Inspect the menu bar status item and popover. Confirm it is compact, glass-like, shows accurate chips, and does not claim scroll, Dock, or hidden menu-bar syncing.
- Confirm the popover stays slim: small Mendy mark, live status rows, short Settings/Permissions/Quit actions, no tutorial layout, no long Command-drag instructions, and no clipped text.
- Inspect Option+Tab glass styling and verify keyboard selection, mouse hover selection, and mouse-click activation use the same selected highlight.
- Confirm Dock & Windows > Switcher discovery diagnostics list total discovered windows, app name, bundle ID, PID, AX window count, CG match status, included/dropped state, and drop/include reason.
- Confirm switcher discovery includes Finder, Terminal, System Settings, Safari, browser windows, and other normal app windows when those apps are open.
- Verify Option+Tab keyboard cycling and modifier-release confirm activate the highlighted card/window.
- Verify Option+Tab hover selection followed by keyboard confirm activates the highlighted card/window.
- Verify Option+Tab mouse click activates the clicked card/window, not a later mutable selection.
- Verify Option+Tab activation with at least two browser windows.
- Verify Option+Tab activation with at least two non-browser app windows.
- Verify Option+Tab activation with two windows from the same app, duplicate or blank titles, and a minimized window.
- When activation fails, capture `WindowActivation` diagnostic fields: source, selectedIndex, highlightedIndex, selectedTitle, selectedCG, selectedPID, selectedBundle, axMatch, frontmostPID/app, focusedCG/title, appMatches, idMatches, and steps.
- Verify Dock preview hover on adjacent Dock items such as Messages/Mail. A wrong neighboring app preview must not appear.
- Verify Dock preview hover on non-running Dock items. No window preview should appear.
- Verify browser multi-window previews with Safari, Chrome, Brave, or another browser.
- Verify first Dock/Option+Tab thumbnail batch timing in Dock & Windows > Dock Previews. A first warm batch on this run reported `requested=10 cached=0 captured=10 duration=382ms`; repeated preview reported `requested=1 cached=1 captured=0 duration=0ms`.
- Verify preview panels appear immediately with placeholders if thumbnails are still loading, then progressively fill in.
- Verify the Dock preview `Preview linger after leaving Dock` slider changes how long the panel remains after the pointer leaves the Dock item and preview panel; record sticky preview or flicker cases.
- Verify Dock preview `Preview animation` and `Animation speed` settings are visible, persist after relaunch, and affect only panel presentation/dismissal.
- Use `Test Preview Animation` to compare System, Fade, Scale, Slide Up, Glass Pop, and None. In the 2026-05-31 agent run the controls were visible and selectable, but the transient test preview did not appear as a separate Computer Use-verifiable window.
- Confirm Snappy, Balanced, and Smooth are noticeably different durations. Expected configured durations are 0.10s, 0.22s, and 0.36s.
- With Reduce Motion enabled in macOS, confirm Dock preview presentation simplifies to None or Fade.
- Hover the macMender Dock item while its Preferences window is visible. Expected result: either one real Preferences/Overview window preview appears, or the preview is suppressed with a clear diagnostic reason. Preview panels, switcher overlays, popovers, and transient windows must never appear.
- Inspect Dock preview and Option+Tab panels for readable Liquid Glass in light and dark appearances.
- Confirm Mendy remains visible and state-driven in onboarding, overview, menu-bar setup, permissions, and popover.

## Still Disabled

- Real menu-bar physical movement, hide/reveal, Always Hidden, secondary bar return, direct reorder, and safe hidden-area Show/Tuck are disabled.
- Do not test those as working features. The expected result is that no reachable UI claims they work.
- `MenuBarItemMover` remains in source only as the scoped future Thaw-style movement guard; app-facing UI should not call it while `physicalMovementEnabled` is false.

## Not Verified by This Agent Run

- Full Dock hover over adjacent Dock icons using the user's actual pointer path after the thumbnail/cache changes.
- Full Option+Tab visual overlay testing via held keyboard shortcut. Computer Use can click the overlay panel and verify mouse activation, but did not deliver a held Option+Tab sequence to the event tap.
- Feel and correctness of the Dock preview linger setting on the user's Dock.
- Visual comparison of all Dock preview animation styles and speeds with an actual preview panel.
- Reduce Motion behavior for Dock preview animations.
- Adjacent Dock hover correctness on the user's Dock.
- Browser multi-window thumbnail correctness.
- Option+Tab exact selected-window activation across minimized windows, duplicate/blank titled windows, and keyboard-confirm paths.
- Safe hidden-area Show/Tuck runtime, because it remains intentionally hidden/disabled.
- Whether macOS accepts drag-to-add in each Privacy & Security pane on the user's OS build.
- Xcode console warning comparison between Xcode Run, `swift run`, `script/build_and_run.sh --verify`, and `open dist/macMender.app`.
