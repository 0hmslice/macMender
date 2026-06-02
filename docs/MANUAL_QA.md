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
- Confirm normal sidebar/page Mendy surfaces remain visually state-distinct without repeat-forever motion while idle.
- Confirm Overview has no `Refresh windows`, `Test preview`, or Mendy `Check status` button. Those controls should not appear on Overview.
- Confirm Overview shows one hero, four high-level status cards, and a collapsed Services disclosure: Permissions, Window Switcher, Dock Previews, and Menu Bar setup.
- Confirm Overview only shows `Open Permissions` when permissions need attention.
- Confirm the sidebar selected row is quiet and does not animate or jump during repeated section switching.
- Confirm the old custom detail header band is gone and the sidebar/content boundary no longer has a clashing top material strip.
- Confirm onboarding shows Accessibility, Screen Recording, and guided Input Monitoring setup.
- Confirm the drag-to-add guidance says to drag the macMender app icon if it is not listed, includes the fallback `+`/reopen instruction, and does not claim permissions are granted.
- Confirm Settings > Menu Bar looks like a safe setup guide, not a broken layout manager.
- Confirm Settings > Menu Bar title reads `Hide Menu Bar Icons`.
- Confirm Settings > Menu Bar shows Command-drag instructions, read-only discovery, session-only "Mark to review" planning controls, and clear disabled states for direct reorder/hide/reveal.
- Confirm Settings > Menu Bar does not show `Safe Hiding Setup`, `Show/Tuck Hidden Area`, layout lanes, fake hidden sections, or automatic third-party icon movement controls.
- Confirm normal Settings > Menu Bar copy does not mention Thaw, runtime transplants, or engine paths. Direct menu-bar icon movement should be described in general user terms as unavailable/disabled.
- Confirm detected menu-bar rows show resolved app icons where possible and fall back gracefully for unresolved/system items.
- Confirm "Mark to review" does not move, hide, persist, or imply any physical menu-bar operation.
- Confirm no fake drag, reorder, move-to-hidden, Always Hidden, checkbox hide, or physical movement controls are reachable.
- Inspect the menu bar status item and popover. Confirm it is compact, glass-like, shows accurate chips, and does not claim scroll, Dock, or hidden menu-bar syncing.
- Confirm the popover stays slim: small Mendy mark, live status rows, short Settings/Permissions/Quit actions, no tutorial layout, no long Command-drag instructions, and no clipped text.
- Inspect Option+Tab glass styling and verify keyboard selection, mouse hover selection, and mouse-click activation use the same selected highlight.
- After a fresh launch, confirm Dock & Windows > Switcher says `Ready to scan` and diagnostics say `No scan yet` before discovery runs. After `Refresh Discovery`, confirm it shows the actual discovered window count.
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
- Verify Dock preview `Preview animation` and `Animation duration` settings are visible, persist after relaunch, and affect only panel presentation/dismissal.
- Use `Test Preview Animation` to compare System, Fade, Scale, Slide Up, Glass Pop, Genie, and None. The test button should show a local sample preview and must not resolve a real Dock item, capture thumbnails, or leave a sticky panel.
- Confirm the Animation Duration slider has a practical range from 0.05s to 0.60s, shows the current value in seconds, and makes short values feel immediate while longer values remain smooth.
- Confirm legacy profiles that previously used Snappy/Balanced/Smooth still open with an equivalent duration and do not show the old speed picker.
- With Reduce Motion enabled in macOS, confirm Dock preview presentation simplifies to None or Fade.
- Hover the macMender Dock item while its Preferences window is visible. Expected result: either one real Preferences/Overview window preview appears, or the preview is suppressed with a clear diagnostic reason. Preview panels, switcher overlays, popovers, and transient windows must never appear.
- Inspect Dock preview and Option+Tab panels for readable Liquid Glass in light and dark appearances.
- Confirm Mendy remains visible and state-driven in onboarding, overview, menu-bar setup, permissions, and popover. Continuous motion should not run on normal sidebar/page avatars while idle.
- Confirm granted Accessibility and Screen Recording cards on Privacy do not show a primary `Request Access` button, while missing permissions still do.
- Confirm Middle Click copy reads as disabled/conditional when the feature is off and no runtime behavior is enabled by default.
- Inspect Overview and Dock & Windows for reduced dark angular shell seams after the post-QA cleanup pass.
- Inspect Overview, Menu Bar, Dock & Windows, Privacy, Profiles, and Advanced for concise user-facing text, aligned content, and no clipped copy.
- Confirm Overview uses `Services`, `Input monitoring`, `Dock previews`, and `Menu bar discovery` instead of raw runtime labels.
- Confirm the Overview reads clearly within five seconds: strong hero, large Mendy, `macMender is running`, compact health chips, four high-level status cards, no filler action area, and service details tucked into disclosure.
- Confirm the sidebar top identity says `macMender`, uses small Mendy, has concise section names, a softer selected state, and a calm bottom service summary.
- Confirm Dock & Windows still shows Window Switcher settings, Dock preview controls, Preview animation, Animation duration, Preview linger, and Test Preview Animation, with raw diagnostics hidden by default.
- Confirm Menu Bar hides repeated `Visible now` labels, bundle IDs, and long planning explanations in the normal row list.
- Confirm Menu Bar rows remain planning-only and use concise states such as `Ready to review`, `Planned for review`, and `System item`.
- Confirm Privacy keeps local config path/details under `Local details`.
- Confirm Privacy shows Accessibility, Screen Recording, and Input Monitoring as calm checklist cards, with granted states quiet and missing states actionable.
- Confirm Advanced keeps dense implementation notes under disclosures.
- Confirm the menu bar popover says `Dock previews`, avoids `Dock Hover` and `Local helpers`, and remains a slim live status dashboard.
- Confirm the menu bar popover says `Menu Bar setup`, uses a small Mendy, avoids tutorial text, and does not claim hidden icon syncing.

## Still Disabled

- Real menu-bar physical movement, hide/reveal, Always Hidden, secondary bar return, direct reorder, and safe hidden-area Show/Tuck are disabled.
- Do not test those as working features. The expected result is that no reachable UI claims they work.
- `MenuBarItemMover` remains in source only as the scoped future Thaw-style movement guard; app-facing UI should not call it while `physicalMovementEnabled` is false.

## Not Verified by This Agent Run

- Full Dock hover over adjacent Dock icons using the user's actual pointer path after the thumbnail/cache changes.
- Popover inspection after the functional UI cleanup pass. Computer Use was unavailable during this agent run, and the menu-bar popover could not be opened reliably through the available tools.
- Full human feel check of the sidebar selection after the native `List(selection:)` investigation fallback. The agent verified screenshots and repeated clicks, but native interaction feel still needs user review.
- Full Option+Tab visual overlay testing via held keyboard shortcut. Computer Use can click the overlay panel and verify mouse activation, but did not deliver a held Option+Tab sequence to the event tap.
- Feel and correctness of the Dock preview linger setting on the user's Dock.
- Visual comparison of all Dock preview animation styles and duration values with an actual preview panel.
- Confirm the presentation-only animation feel pass: System has a small scale/drift, Fade is opacity-only, Scale grows from visibly smaller to normal, Slide Up travels clearly from the Dock direction, Glass Pop has a one-shot overshoot/highlight, Genie expands elastically from a narrower Dock-origin layer transform, and None is instant.
- Confirm moving quickly between Dock icons cancels stale animations cleanly without sticky previews or delayed panels.
- Confirm Test Preview Animation uses the current style/duration, auto-dismisses, and returns status to `Ready to scan` after dismissal.
- Reduce Motion behavior for Dock preview animations.
- Adjacent Dock hover correctness on the user's Dock.
- Browser multi-window thumbnail correctness.
- Option+Tab exact selected-window activation across minimized windows, duplicate/blank titled windows, and keyboard-confirm paths.
- Safe hidden-area Show/Tuck runtime, because it remains intentionally hidden/disabled.
- Whether macOS accepts drag-to-add in each Privacy & Security pane on the user's OS build.
- Xcode console warning comparison between Xcode Run, `swift run`, `script/build_and_run.sh --verify`, and `open dist/macMender.app`.
