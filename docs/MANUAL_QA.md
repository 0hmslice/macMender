# Manual QA

Use this file for verification that cannot be proven by `swift build` or `swift test`.

## Launch Method

- Use `script/build_and_run.sh --verify` or `open dist/macMender.app` for permissions, bundle identity, app status item, Dock previews, and Window Switcher testing.
- Do not trust raw SwiftPM executable or Xcode SwiftPM-run behavior for Privacy & Security identity tests.
- In packaged-app logs, confirm startup diagnostics report a non-nil bundle identifier and a `.app` bundle path.
- Treat repeated `com.apple.linkd.autoShortcut` warnings as harmless system/Xcode noise unless macMender later adopts App Intents or Shortcuts.

## Phase A Environment and State Safety

- The compatibility target for this pass is macOS 27.0 build `26A5388g`, Darwin 27.0.0, arm64, Xcode 27.0 beta (`27A5228h`), and Apple Swift 6.4.
- Use `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` for Xcode-based commands without changing the global `xcode-select` setting.
- Before any stateful test, preserve the app config and record whether each spacing key is missing or has an explicit value. A missing key and integer `0` are different states.
- The original spacing state for this Phase A run was current-host integer `0` for both keys; the any-host/global versions were absent. Restore that exact state after testing.
- Do not use `script/build_and_run.sh --fresh` without an explicit restoration plan; it moves the live config aside and does not restore it automatically.
- The untouched baseline passed 72 tests in 8 suites and packaged verification. It showed an Overview window in approximately 1.43 seconds, sampled 0.0% idle CPU, and used approximately 55–56 MB resident memory with preferences open and approximately 62 MB with preferences closed.
- The final Phase A build passed `swift build`, 95 tests in 9 suites, and packaged verification. The packaged app showed its first window in approximately 1.009 seconds, and the detailed live results and residuals are recorded below.

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
- Confirm the sidebar has a Menu Bar Spacing section but no Menu Bar management section.
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
- Confirm General no longer contains Menu Bar Spacing.
- Confirm Menu Bar Spacing is its own section with System Default, Compact, Comfortable, Wide, Custom, an Icon spacing slider, Apply, and Reset to Default.
- Confirm Menu Bar Spacing copy says it only changes spacing and does not move, hide, or manage individual icons.

### macOS 27 Beta 4 Menu Bar Spacing

- Confirm the exact OS build before interpreting the result. `Unsupported on this beta` is the expected Apple-item classification only for build `26A5388g`; another macOS 27 build should report `Could not confirm system item update` until measured.
- Record the current-host and any-host/global state of `NSStatusItemSpacing` and `NSStatusItemSelectionPadding`, including whether each key is absent, before pressing Apply.
- Apply values `0`, `4`, `8`, `16`, `24`, and `32` in a controlled sequence. After each Apply, confirm both current-host keys contain the requested integer.
- On build `26A5388g`, confirm Apply reports `Unsupported on this beta`, says the preference was saved, identifies Apple system items as unaffected, and does not claim that system items updated.
- Confirm Apply on build `26A5388g` does not restart Control Center, MenuBarAgent, or SystemUIServer. A brief Apple-item reload is not expected on this build.
- Confirm macMender's own status item changes across the complete range, remains clickable at `0`, and continues to open the same compact popover.
- Confirm Wi-Fi, sound, battery, Control Center, and clock frames remain unchanged across the range. This is the documented macOS 27 Beta 4 limitation, not a successful Apple-item adjustment.
- Use `script/status_item_spacing_probe.swift` if a fresh AppKit probe-item check is needed. Confirm fresh probe items honor the requested value; do not automatically relaunch or terminate unrelated third-party apps.
- If manually relaunching one suitable third-party status-item app is safe, record whether its recreated item honors the preference. Do not generalize the result to Apple items or every third-party app.
- Use Reset to Default and confirm the status says System Default was restored while continuing to describe the Apple-item beta limitation honestly; it must not claim a host refresh occurred on `26A5388g`.
- After Reset to Default, confirm `defaults -currentHost read -globalDomain NSStatusItemSpacing` and `defaults -currentHost read -globalDomain NSStatusItemSelectionPadding` both fail/miss, and relaunching macMender does not rewrite them.
- Restore the exact original key state after the matrix. For this Phase A run that means explicit current-host `0/0`, not missing keys.
- Confirm Reset to Onboarding is in Advanced Recovery Tools.
- Confirm Safe Mode is in Advanced and explains that it pauses active input monitoring, Dock previews, Window Switcher shortcuts, and experimental input features.
- Confirm the floating top-right shell pause/refresh controls are gone.
- Confirm Advanced `Status Refresh` shows progress and then `Updated just now`; it must not trigger window discovery or thumbnail capture.
- Confirm Advanced contains Services/Technical Status details.
- Confirm Advanced has a Configuration section separate from Recovery Tools.
- Confirm Save Now reports that current settings were written to disk.
- Confirm Export Config can write a `macMender-config.json` file.
- Confirm Import Config opens a file picker for JSON files and shows confirmation before replacing current profiles and app settings.
- Import a valid exported config and confirm visible settings update immediately, selected profile is valid, and runtime services remain responsive.
- Confirm importing a config creates a `config-backup-*.json` file in the macMender Application Support folder.
- Confirm importing invalid JSON is rejected with readable feedback and does not replace current settings.
- Confirm imported macOS permission-shaped JSON does not make permissions appear granted; Privacy must continue to show live system permission status.
- Confirm importing Menu Bar Spacing stores the setting but does not write `NSStatusItemSpacing` or `NSStatusItemSelectionPadding` until the user presses Apply on the Menu Bar Spacing page.
- Confirm default/new profile Middle Click behavior is enabled three-finger tap mapped to middle click.
- Confirm section-specific Mendy art appears on Overview, General, Input, Dock & Windows, Privacy, Advanced, and Profiles, using generic Mendy only for compact state accents.
- With two or more profiles, confirm the top-right profile switcher uses one profile-oriented symbol, opens the profile menu, switches profiles, and has no clipped text.
- Create Profile A and Profile B. Change Profile A's Dock preview animation style, animation duration, and Three-Finger Tap / Middle Click setting, switch to Profile B, and confirm those visible controls update to Profile B's values.
- Change Profile B's Dock preview and Three-Finger Tap / Middle Click values, switch back to Profile A, and confirm Profile A's values return without needing an app relaunch.
- Confirm Overview and the status-item popover update their Three-Finger Tap, Dock previews, and Window Switcher summaries after each profile switch.
- Confirm the top-right profile switcher appears immediately after creating a second profile and disappears only after returning to one profile.
- Confirm Launch at Login, Dock icon visibility, Safe Mode, permission status, onboarding completion, and Menu Bar Spacing behave as app-wide settings rather than per-profile settings.
- Confirm Menu Bar Spacing does not silently write or refresh system defaults when switching profiles.
- Confirm Dock & Windows still shows Window Switcher settings, Dock preview controls, Preview animation, Animation duration, Preview linger, and Test Preview Animation.
- Confirm the Dock preview animation picker only shows System, Fade, Scale, Slide Up, and None.
- Confirm old saved Glass Pop and Genie settings map to safe styles instead of appearing as selectable options.
- Confirm Slide Up rises from the Dock direction and dismisses back toward the Dock.
- Confirm Dock preview dismissal does not jump left/down and does not leave stale transforms.
- Confirm Fade is opacity-only, None is instant, and Scale has no diagonal drift.
- Confirm `Test Preview Animation` still shows a local sample preview and does not leave a sticky panel.
- Confirm Option+Tab still discovers normal apps and activates the selected window.
- With the Window Switcher inactive, confirm Escape passes through to the frontmost app using a screen or control where Escape has an observable native effect.
- With the Window Switcher active, confirm Escape dismisses only the overlay and does not activate a window.
- Close all real Finder windows and confirm Finder contributes neither a fake Option+Tab entry nor a Dock preview for its desktop AX element.
- Open a real Finder window and confirm that real window appears in Option+Tab and the Finder Dock preview.
- Open multiple windows in a browser and confirm each preview has the correct title, thumbnail or icon fallback, selection, and activation target.
- Hover macMender's Dock icon and confirm only its real preferences window is previewed; transient panels, popovers, and system dialogs must not appear as self-preview windows.
- Confirm Dock preview hover still uses correct app/window identity and does not show neighboring Dock item previews.
- While a Dock preview is visible, right-click its Dock icon and confirm the preview dismisses, the real Dock context menu remains usable, and the preview does not immediately re-present over the menu.
- Repeat the Dock context-menu check with Control-click, then confirm normal preview presentation resumes after the interaction ends.
- Confirm settings stay responsive while changing visual-only Dock preview settings.
- Confirm packaged-app idle CPU settles near baseline after the window is idle for several seconds. Recheck with `top -l 5 -s 1 -pid $(pgrep -x macMender | head -n1)` or Activity Monitor.
- Sample idle CPU on every page and while the status-item popover is open; no page or popover should sustain an update loop after interaction stops.
- Recheck resident memory after Dock previews, browser windows, Finder filtering, and Option+Tab use; record any persistent growth relative to the untouched baseline.

## Menu Bar Management Status

Menu Bar management is removed/deferred. Do not test it as an active feature.

Expected current result:

- No full Menu Bar management page.
- No Menu Bar setup status card.
- No Menu Bar setup row in the popover.
- No Menu Bar scanner status on Overview.
- No Menu Bar discovery list.
- No Command-drag tutorial.
- No Mark to Review checklist.
- No hidden-area, Show/Tuck, Always Hidden, or physical movement controls.
- No `MenuBarItemMover` reachable path.
- The limited Menu Bar Spacing section exists. It must only adjust/reset the system-wide status-item spacing preferences and must not expose scanner, mover, reveal, hidden area, Show/Tuck, or icon grouping controls.

Historical menu-bar research and QA scripts live under `docs/archive/menu-bar-removed-2026-06-02/` and are not current product direction.

## Mendy Asset Source

Root `Mendy/` contains the user-provided source/reference PNGs. `Sources/macMender/Resources/Mendy/` contains the copied runtime resources bundled by SwiftPM with matching filenames.

## Phase A Packaged Result

- Launch, first-visible timing, status-item presence, every page, the popover, onboarding, profiles, config import/export, live permission status/actions, Safe Mode, and Overview card navigation passed.
- Dock hover and adjacent-item identity, Finder fake-window filtering with and without a real Finder window, browser multi-window previews/activation, macMender self-preview, preview animation, and Control-click context-menu suppression passed.
- Global Option+Tab keyboard activation, mouse activation, active Escape dismissal, and inactive Escape passthrough passed.
- The controlled spacing range, exact-build status copy, own-item geometry, true System Default deletion, and exact state restoration passed. Apple/system items remained unchanged as documented for build `26A5388g`.
- Light and dark appearance passed. Reduce Motion and Reduce Transparency were enabled, confirmed through AppKit, exercised with the packaged UI and preview test, then restored to their exact original values.
- Page samples settled at 0.0% CPU except one transient 0.2% Advanced sample. The popover held at 0.0%. Clean-launch memory ranged from approximately 56 MB to 88 MB after the complete page/popover sweep; a prior thumbnail-heavy run reached approximately 138 MB and returned to baseline range after relaunch.
- The live config is byte-identical to the pre-QA copy. Current-host spacing is explicit `0/0`, both any-host/global keys are absent, Dock-icon visibility is restored, and temporary QA exports/backups were moved to `/tmp/macmender-phase-a-qa-artifacts.9419PT` rather than deleted.

## Remaining Manual/Hardware Checks

- Perform an actual three-finger tap on hardware and compare physical external-mouse versus built-in-trackpad scrolling feel. Automation verified the controls and runtime status but cannot reproduce those gestures faithfully.
- Test any exposed Magic Mouse or Magic Trackpad-specific rule on the matching hardware. Static review found that the current event classifier selects built-in trackpad or external mouse at runtime and does not independently select the saved Magic-device rule types. This predates Phase A and was not changed because no macOS 27 compatibility regression was confirmed.
- Perform a physical secondary-click on the macMender Dock icon while its preview is visible. Synthetic right-click was inconclusive; Control-click produced the real Dock menu and suppression/recovery passed, and the secondary-interaction classifier is unit-tested.
- Resize onboarding slightly below the intended packaged window size and visually confirm that the drag-to-add permission guide remains unclipped. The complete flow and intended-size/scrolled layout passed automation.
- Optionally relaunch one suitable third-party status-item app by hand to compare it with the fresh AppKit probe. Do not generalize one app's behavior to all third-party frameworks.
- A human can still perform a subjective cursor/beachball feel check and a dedicated GPU/Instruments trace. Automation observed a responsive first window and no sustained CPU update loop.
