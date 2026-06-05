# Manual QA

Use this file for verification that cannot be proven by `swift build` or `swift test`.

## Launch Method

- Use `script/build_and_run.sh --verify` or `open dist/macMender.app` for permissions, bundle identity, app status item, Dock previews, and Window Switcher testing.
- Do not trust raw SwiftPM executable or Xcode SwiftPM-run behavior for Privacy & Security identity tests.
- In packaged-app logs, confirm startup diagnostics report a non-nil bundle identifier and a `.app` bundle path.
- Treat repeated `com.apple.linkd.autoShortcut` warnings as harmless system/Xcode noise unless macMender later adopts App Intents or Shortcuts.

## Current Pass Checklist

- Launch `dist/macMender.app` and inspect onboarding, Overview, General, Input, Dock & Windows, Profiles, Privacy, and Advanced.
- Confirm onboarding is a multi-step flow with Welcome, Input and Three-Finger Tap, Dock and Windows, Permissions, Local Privacy, and Finish.
- Confirm the onboarding header is compact and does not crowd the step content.
- Confirm onboarding has no Menu Bar management content.
- Confirm onboarding reports Accessibility, Screen Recording, and Input Monitoring from real permission status.
- Confirm Input Monitoring is separate from three-finger gesture runtime state.
- Confirm onboarding `Recheck Permissions` refreshes permission status without running window discovery or thumbnail capture.
- Confirm drag-to-add Privacy & Security guidance is present and phrases drag-to-add as conditional guidance, with + button fallback.
- Confirm the Permissions drag-to-add guide stays stable at the intended packaged-app window size and when resized slightly smaller; it must not overlap or clip the app tile, arrow, mock permission list, or numbered guidance.
- Confirm onboarding uses section-specific Mendy assets: Overview for Welcome/Finish, Input for Three-Finger Tap, Dock & Windows for Dock/Window setup, and Privacy for permissions/privacy.
- Confirm onboarding can be skipped or finished even when permissions are deferred.
- Confirm Advanced `Reset to Onboarding` still returns to the multi-step flow.
- Confirm the sidebar has no Menu Bar section.
- Confirm Overview has no Menu Bar setup card, chip, status row, scanner status, hidden-area language, Command-drag tutorial, Mark to Review checklist, or menu-bar icon hiding claim.
- Confirm Overview shows Permissions, Three-Finger Tap, Window Switcher, and Dock Previews as key status cards.
- Confirm Overview does not show `Status Refresh` or a `Services` technical disclosure.
- Confirm the app still has its own macMender status item in the macOS menu bar.
- Confirm the status-item popover is compact, opens quickly, has no clipped text, and shows only: running state, Permissions summary, Three-Finger Tap, Dock previews, Window Switcher, Open macMender, an as-needed Permissions button, and low-priority Quit.
- Confirm the popover does not show separate Accessibility and Screen Recording rows when permissions are healthy.
- Confirm the popover has no Menu Bar management rows, setup copy, Command-drag copy, Mark to Review, hidden icon language, Show/Tuck, scanner/discovery language, diagnostics, or thumbnail/discovery work.
- Confirm popover actions work: Open macMender focuses the settings window, Permissions opens Privacy when shown, and Quit exits the app.
- Confirm Privacy contains only the privacy promise, local data details, Accessibility, Screen Recording, and Input Monitoring permission/runtime status.
- Confirm Input Monitoring reports `Granted` only when macOS listen-event access is granted, and keeps gesture runtime state separate as Active, Off, or Needs Permission.
- Confirm Launch at Login is in General.
- Confirm Dock icon behavior is in General.
- Confirm General contains a Menu Bar Spacing section with System Default, Compact, Comfortable, Wide, Apply, and Reset to Default.
- Confirm Menu Bar Spacing copy says it only changes spacing and does not move, hide, reorder, reveal, or manage individual icons.
- Apply Compact, Comfortable, and Wide if safe for the test machine, then confirm a status message appears. Some menu bar apps may require relaunch or logout before the visual spacing fully updates.
- Use Reset to Default and confirm the status message says system default was restored.
- Confirm Reset to Onboarding is in Advanced Recovery Tools.
- Confirm Safe Mode is in Advanced and explains that it pauses active input monitoring, Dock previews, Window Switcher shortcuts, and experimental input features.
- Confirm the floating top-right shell pause/refresh controls are gone.
- Confirm Advanced `Status Refresh` shows progress and then `Updated just now`; it must not trigger window discovery or thumbnail capture.
- Confirm Advanced contains Services/Technical Status details.
- Confirm default/new profile Middle Click behavior is enabled three-finger tap mapped to middle click.
- Confirm section-specific Mendy art appears on Overview, General, Input, Dock & Windows, Privacy, Advanced, and Profiles, using generic Mendy only for compact state accents.
- With two or more profiles, confirm the top-right profile switcher uses one profile-oriented symbol, opens the profile menu, switches profiles, and has no clipped text.
- Confirm Dock & Windows still shows Window Switcher settings, Dock preview controls, Preview animation, Animation duration, Preview linger, and Test Preview Animation.
- Confirm the Dock preview animation picker only shows System, Fade, Scale, Slide Up, and None.
- Confirm old saved Glass Pop and Genie settings map to safe styles instead of appearing as selectable options.
- Confirm Slide Up rises from the Dock direction and dismisses back toward the Dock.
- Confirm Dock preview dismissal does not jump left/down and does not leave stale transforms.
- Confirm Fade is opacity-only, None is instant, and Scale has no diagonal drift.
- Confirm `Test Preview Animation` still shows a local sample preview and does not leave a sticky panel.
- Confirm Option+Tab still discovers normal apps and activates the selected window.
- Confirm Dock preview hover still uses correct app/window identity and does not show neighboring Dock item previews.
- Confirm settings stay responsive while changing visual-only Dock preview settings.
- Confirm packaged-app idle CPU settles near baseline after the window is idle for several seconds. Recheck with `top -l 5 -s 1 -pid $(pgrep -x macMender | head -n1)` or Activity Monitor.

## Menu Bar Management Status

Menu Bar management is removed/deferred. Do not test it as an active feature.

Expected current result:

- No Menu Bar page.
- No Menu Bar setup status card.
- No Menu Bar setup row in the popover.
- No Menu Bar scanner status on Overview.
- No Menu Bar discovery list.
- No Command-drag tutorial.
- No Mark to Review checklist.
- No hidden-area, Show/Tuck, Always Hidden, or physical movement controls.
- No `MenuBarItemMover` reachable path.
- A limited General > Menu Bar Spacing preference may exist. It must only adjust/reset system item spacing and must not expose scanner, mover, reveal, hidden area, Show/Tuck, or icon grouping controls.

Historical menu-bar research and QA scripts live under `docs/archive/menu-bar-removed-2026-06-02/` and are not current product direction.

## Mendy Asset Source

Root `Mendy/` contains the user-provided source/reference PNGs. `Sources/macMender/Resources/Mendy/` contains the copied runtime resources bundled by SwiftPM with matching filenames.

## Not Verified by This Agent Run

- Full human feel check of packaged-app launch cursor behavior on the user's M2 Mac.
- Full Dock hover over adjacent Dock icons using the user's actual pointer path.
- Full Option+Tab visual overlay testing via held keyboard shortcut.
- Browser multi-window thumbnail correctness.
- Reduce Motion behavior for Dock preview animations.
