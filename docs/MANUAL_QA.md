# Manual QA

Use this file for verification that cannot be proven by `swift build` or `swift test`.

## Launch Method

- Use `script/build_and_run.sh --verify` or `open dist/macMender.app` for permissions, bundle identity, app status item, Dock previews, and Window Switcher testing.
- Do not trust raw SwiftPM executable or Xcode SwiftPM-run behavior for Privacy & Security identity tests.
- In packaged-app logs, confirm startup diagnostics report a non-nil bundle identifier and a `.app` bundle path.
- Treat repeated `com.apple.linkd.autoShortcut` warnings as harmless system/Xcode noise unless macMender later adopts App Intents or Shortcuts.

## Current Pass Checklist

- Launch `dist/macMender.app` and inspect onboarding, Overview, General, Input, Dock & Windows, Profiles, Privacy, and Advanced.
- Confirm the sidebar has no Menu Bar section.
- Confirm Overview has no Menu Bar setup card, chip, status row, scanner status, hidden-area language, Command-drag tutorial, Mark to Review checklist, or menu-bar icon hiding claim.
- Confirm the app still has its own macMender status item in the macOS menu bar and that its popover opens Settings/Permissions/Quit without Menu Bar management rows.
- Confirm Privacy contains only the privacy promise, local data details, Accessibility, Screen Recording, and Input Monitoring guidance.
- Confirm Launch at Login is in General.
- Confirm Dock icon behavior is in General.
- Confirm Reset to Onboarding is in Advanced Recovery Tools.
- Confirm Safe Mode is in Advanced and explains that it pauses active input monitoring, Dock previews, Window Switcher shortcuts, and experimental input features.
- Confirm the floating top-right shell pause/refresh controls are gone.
- Confirm Overview `Status Refresh` shows progress and then `Updated just now`; it must not trigger window discovery or thumbnail capture.
- Confirm Dock & Windows still shows Window Switcher settings, Dock preview controls, Preview animation, Animation duration, Preview linger, and Test Preview Animation.
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

Historical menu-bar research and QA scripts live under `docs/archive/menu-bar-removed-2026-06-02/` and are not current product direction.

## Not Verified by This Agent Run

- Full human feel check of packaged-app launch cursor behavior on the user's M2 Mac.
- Full Dock hover over adjacent Dock icons using the user's actual pointer path.
- Full Option+Tab visual overlay testing via held keyboard shortcut.
- Browser multi-window thumbnail correctness.
- Reduce Motion behavior for Dock preview animations.
