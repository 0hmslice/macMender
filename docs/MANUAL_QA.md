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
- Confirm onboarding shows Accessibility, Screen Recording, and guided Input Monitoring setup.
- Confirm the drag-to-add guidance says to drag the macMender app icon if it is not listed, includes the fallback `+`/reopen instruction, and does not claim permissions are granted.
- Confirm Settings > Menu Bar looks like a safe setup guide, not a broken layout manager.
- Confirm Settings > Menu Bar title reads `Safe Menu Bar Setup`.
- Confirm Settings > Menu Bar shows Command-drag instructions, practical cleanup guidance, read-only discovery, session-only "Mark to review" planning controls, and clear disabled states for direct reorder/hide/reveal.
- Confirm "Mark to review" does not move, hide, persist, or imply any physical menu-bar operation.
- Confirm no fake drag, reorder, move-to-hidden, Always Hidden, checkbox hide, or physical movement controls are reachable.
- Inspect the menu bar status item and popover. Confirm it is compact, glass-like, shows accurate chips, and does not claim scroll, Dock, or hidden menu-bar syncing.
- Inspect Option+Tab glass styling and verify keyboard selection, mouse hover selection, and mouse-click activation use the same selected highlight.
- Verify Option+Tab activation with browser windows where it previously worked.
- Verify Option+Tab activation with non-browser apps where it may fail.
- Verify Option+Tab activation with two windows from the same app, duplicate or blank titles, and a minimized window.
- Verify Dock preview hover on adjacent Dock items such as Messages/Mail. A wrong neighboring app preview must not appear.
- Verify Dock preview hover on non-running Dock items. No window preview should appear.
- Verify browser multi-window previews with Safari, Chrome, Brave, or another browser.
- Verify the Dock preview `Preview idle timeout` slider changes how long the panel remains after the pointer leaves the Dock item and preview panel; record sticky preview or flicker cases.
- Inspect Dock preview and Option+Tab panels for readable Liquid Glass in light and dark appearances.
- Confirm Mendy remains visible and state-driven in onboarding, overview, menu-bar setup, permissions, and popover.

## Still Disabled

- Real menu-bar physical movement, hide/reveal, Always Hidden, secondary bar return, and direct reorder are disabled.
- Do not test those as working features. The expected result is that no reachable UI claims they work.
- `MenuBarItemMover` remains in source only as the scoped future Thaw-style movement guard; app-facing UI should not call it while `physicalMovementEnabled` is false.

## Not Verified by This Agent Run

- Visual UI inspection of the launched app.
- Feel and correctness of the new Dock preview idle timeout on the user's Dock.
- Adjacent Dock hover correctness on the user's Dock.
- Browser multi-window thumbnail correctness.
- Option+Tab exact selected-window activation across non-browser apps and minimized windows.
- Whether macOS accepts drag-to-add in each Privacy & Security pane on the user's OS build.
- Xcode console warning comparison between Xcode Run, `swift run`, `script/build_and_run.sh --verify`, and `open dist/macMender.app`.
