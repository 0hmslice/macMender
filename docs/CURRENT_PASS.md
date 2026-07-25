# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/macos27-ui-rebrand`

## Focus

Phase A macOS 27 compatibility was completed and committed separately on `codex/macos27-compatibility` through `487a832`. Phase B is the current visual rebrand. Its presentation milestone is `b4c2707` (`Restyle onboarding popover and overlays`), followed by the final accessibility/performance QA milestone. Compatibility and presentation changes remain separated in Git history.

Final packaged Phase B QA is recorded in `docs/UI_REBRAND_QA.md`. Build, tests, package verification, targeted packaged UI, targeted dark/light appearance, and page performance passed. The evidence record marks carried-forward Phase A checks and named physical-device, spoken-VoiceOver, global-accessibility-mode, final popover, minimum-size-onboarding, and ScreenCaptureKit-redacted Profiles checks as partial/manual.

Menu Bar management remains removed/deferred. Menu Bar Spacing remains a narrow app-wide utility that can only read, write, or delete the two global spacing preferences; it does not inspect or manage individual menu bar items.

## Test Environment

- macOS: 27.0
- Build: `26A5388g`
- Kernel: Darwin 27.0.0, `xnu-13432.0.94.501.4~1/RELEASE_ARM64_T8112`
- Architecture: arm64
- Xcode: 27.0 (`27A5228h`)
- Swift: Apple Swift 6.4 (`swiftlang-6.4.0.27.1 clang-2100.3.27.1`)
- Swift target: `arm64-apple-macosx27.0.0`

The selected developer directory is Command Line Tools. Xcode-based commands in this pass use `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` without changing the user's global `xcode-select` setting.

## Phase B Implementation Status

- Design research and sources are recorded in `docs/UI_REBRAND_RESEARCH.md`.
- The app uses a native `NavigationSplitView`, sidebar `List`, toolbar profile picker, shared semantic design tokens, restrained content surfaces, and functional glass for navigation and overlays.
- Overview, General, Input, Dock & Windows, Menu Bar Spacing, Profiles, Privacy, Advanced, onboarding, the status-item popover, Dock previews, and Option+Tab presentation have been redesigned.
- Mendy is absent from routine pages, navigation, the app icon, and the popover. It remains only in onboarding Welcome/Finish; its assets were not deleted.
- The approved app identity is a modern notched MacBook with a sewn upper-right display repair. Its revised blue/slate lighting remains legible beside standard Apple icons in a dark or translucent Dock. The status item uses an independently authored MacBook template glyph with a three-stitch upper-right repair, rendered from precise paths so it remains crisp and adaptive at menu-bar size.
- The popover is now a focused quick-control surface: Three-Finger Tap, reverse external-mouse scrolling, Dock Previews, and Window Switcher use native switches aligned to one trailing control column; Open macMender and Quit are always visible. Healthy permission, profile, and runtime prose is omitted. An actionable warning appears only for missing Accessibility or Safe Mode.
- The popover uses a lighter ultra-thin system material with an opaque Reduce Transparency fallback. Its footer and content window are fitted tightly so Open macMender and Quit no longer sit above an empty lower chin.
- Opening macMender from the popover always restores Overview and the full sidebar, including after Profiles was selected with the sidebar collapsed.
- Changing destinations also restores the complete navigation split view, preventing Profiles or another content-initiated destination from becoming a detail-only dead end.
- On the tested macOS 27 beta, the former Profiles hierarchy rendered its full-height collection as placeholder or blank pixels and could visually suppress the split-view content even though the accessibility tree remained populated. Controlled static and profile-data diagnostics rendered normally, ruling out profile storage and app-authored privacy redaction. Profiles now uses one width-constrained scrolling page with lightweight selectable rows, while profile naming occurs in a focused sheet. Storage, activation, creation, and deletion behavior are unchanged.
- Window Switcher Strip now has a distinct single-row presentation modeled on the native macOS switcher, but uses live window previews in place of app icons. It scrolls the selected preview into view while preserving the existing discovery, filtering, activation, and Escape paths.
- Routine active-state labels are quiet text. Color and symbols are reserved for states that need attention, are unavailable, or are paused.
- Dock preview and Option+Tab presentation changed visually only. Identity, discovery, Finder filtering, thumbnail capture/cache, activation, panel lifetime, Dock context-menu suppression, and Escape routing remain unchanged.
- Final source verification before the quick-controls/Strip follow-up passed `swift build` and 99 tests in 10 suites. The follow-up expands the suite to 103 tests in 11 suites; its final gate is recorded in `docs/UI_REBRAND_QA.md`.
- `script/build_and_run.sh --verify` passed. The packaged app launched, every destination was inspected through visual capture or its complete accessibility tree, the isolated standard-size onboarding flow passed, targeted light/dark checks passed with documented capture limitations, and every page settled to 0.0% CPU. Final `top` memory ranged from approximately 51 MB at clean Overview to 95 MB at the heaviest page sample.
- Accessibility audit fixes use semantic primary status text, stronger contrast-aware borders, contextual Input labels/values/hints, native selected onboarding rows with a non-color checkmark, and wrapping/scrolling popover fallbacks. Full spoken/global-mode checks remain manual because the macOS Accessibility settings pane closed the Computer Use connection.
- Profiles currently supports create, select, Make Active, and delete. Rename and Duplicate remain unimplemented; this is a disclosed Phase B gap and must not be reported as complete.

## Phase A Untouched Baseline (Historical)

Before the compatibility implementation:

- `swift build`: passed with Xcode 27 selected command-locally.
- `swift test`: 72 tests in 8 suites passed.
- `script/build_and_run.sh --verify`: passed.
- Packaged app: launched and exposed its Overview window in approximately 1.43 seconds, including automation overhead.
- Status item: present and opened the macMender popover.
- Idle with preferences open: 0.0% sampled CPU and approximately 55–56 MB resident memory.
- Idle with preferences closed: 0.0% sampled CPU and approximately 62 MB resident memory.
- Current-host `NSStatusItemSpacing`: present integer `0`.
- Current-host `NSStatusItemSelectionPadding`: present integer `0`.
- Any-host/global versions of both spacing keys: absent.

The original spacing state was explicit `0/0`, not System Default, and the controlled diagnostic matrix restored that exact state.

## macOS 27 Menu Bar Spacing Result

Verified on build `26A5388g`:

- Changing the paired values in `AnyApplication / CurrentUser / CurrentHost` changes freshly created AppKit probe-item widths from System Default through `32`.
- No replacement domain or host scope for Apple/system items was found. The paired-key probe does not prove that none exists.
- Existing third-party items may need their owning app to recreate the status item before a new value appears; macMender does not do that automatically.
- Apple items such as Wi-Fi, sound, battery, Control Center, and clock do not change at values `0`, `4`, `8`, `16`, `24`, or `32`.
- The diagnostic found those Apple items in the macOS 27 `MenuBarAgent` accessibility tree.
- At explicit value `32`, restarting Control Center or MenuBarAgent did not update those Apple item frames.
- The diagnostic found no top-edge system-item tree under SystemUIServer. SystemUIServer was not restarted, so this pass makes no measured claim about its effectiveness.

The compatibility evidence, research sources, upstream licenses, and controlled measurements are recorded in `docs/MACOS_27_COMPATIBILITY.md`.

## Compatibility Strategy

- Earlier supported macOS versions retain the existing current-host preference and Control Center refresh strategy.
- Exact build `26A5388g` writes and verifies the preference for AppKit compatibility, updates macMender's own status item, uses no host restart because no safe confirmed refresh path was established, and reports `Unsupported on this beta` for Apple items. Control Center and MenuBarAgent were ineffective at `32`; SystemUIServer was not tested.
- Other macOS 27 builds remain unconfirmed until measured. They retain the preference without claiming Apple-item success or attempting an unverified host restart.
- Apply writes both keys and reads them back before the app stores the selected preference.
- A partial write or verification mismatch attempts to restore each key to its original value and reports failure instead of success.
- System Default deletes both keys; no spacing keys are written for the default state.
- Imported spacing remains stored only and is not applied until the user presses Apply.

The implementation does not automatically relaunch third-party apps.

## Phase A Post-Fix Verification (Historical)

- `swift build`: passed.
- `swift test`: 95 tests in 9 suites passed. The Menu Bar Spacing suite contains 23 tests covering OS strategy selection, domain/value mapping, true System Default deletion, refresh selection, result copy, clamping, staged verification, rollback/readback ordering, failure handling, stale-read cancellation, production Apply ordering, and macMender status-item geometry.
- `script/build_and_run.sh --verify`: passed.
- Packaged first-visible window: approximately 1.009 seconds, including automation overhead.
- Packaged spacing UI: presets, custom slider, Apply, Reset, and exact-build status copy passed.
- Exact Beta 4 custom Apply: both current-host keys were verified; macMender updated immediately; Apple/system items remained unchanged; Control Center, MenuBarAgent, and SystemUIServer PIDs remained unchanged.
- True System Default: both keys were absent. Explicit `16` and absent-key System Default both produced a 40-point macMender Accessibility frame, mirroring the controlled probe's Default-equals-`16` relationship; restored custom `0` produced the expected 24-point post-fix frame.
- Launch, onboarding, Overview card routing, General, Input controls, Dock previews, Window Switcher, profiles, Privacy, Advanced, config import/export, status-item popover, light/dark appearance, Reduce Motion, and Reduce Transparency passed packaged-app QA.
- Real Finder no-window/real-window filtering, browser multi-window previews and activation, macMender self-preview, adjacent Dock identity, Control-click Dock context-menu suppression, keyboard/mouse Option+Tab activation, active Escape dismissal, and inactive Escape passthrough passed.
- Idle page samples settled at 0.0% CPU, except one transient 0.2% Advanced sample that returned to 0.0%. Clean-launch memory began at approximately 56 MB and reached approximately 88 MB after visiting every page and holding the popover open. A thumbnail-heavy run reached approximately 138 MB; a clean relaunch returned to baseline-range memory.
- The live config is byte-identical to its pre-QA backup (`SHA-256 2b219eab20ea6d00912a67cdfbee03f99bfd8d25be31fbb296df88a43d1960c6`). Current-host spacing is restored to explicit `0/0`; both any-host/global keys are absent. Dark mode and the original accessibility-display preferences are restored.

Primary manual hardware residuals are a physical three-finger tap, separate physical external-mouse/trackpad scrolling feel, a physical secondary-click Dock-menu check, and the documented pre-existing Magic-device rule-selection gap. Synthetic right-click was inconclusive; Control-click and the suppression classifier tests passed. No confirmed macOS 27 regression was found in those unchanged systems. The complete residual list is in `docs/MANUAL_QA.md`.

## Settings Ownership Preserved

Profile-specific settings remain Input and scrolling, Three-Finger Tap / Middle Click, Dock previews, Window Switcher, and Dock profile values.

App-wide settings remain Launch at Login, Dock icon visibility, onboarding completion, Safe Mode, live permission status, the macMender status item, and Menu Bar Spacing.

Profile switching must not write spacing defaults, restart a menu bar host, or change an app-wide spacing selection.

## Boundaries Preserved

- No Menu Bar scanner, runtime, mover, hidden area, Show/Tuck, item grouping, searching, or XPC/helper system was restored.
- Developer-only spacing probes are not part of the app target and do not create a shipping menu bar management path.
- Menu Bar Spacing does not inspect third-party menu bar items or automatically relaunch, terminate, move, or hide a third-party app or item.
- No GPL source was copied. GPL projects were inspected for behavior only.
- Phase B restyled the Dock preview and Option+Tab views, but did not change Dock identity matching, discovery, Finder filtering, thumbnail capture/cache, Dock context-menu suppression, activation, panel lifetime, or Escape routing.
- Input, scrolling, Three-Finger Tap, profiles, config import/export, permissions, and Dock preference behavior were not changed.
- Bundle identifier, signing, entitlements, public/top-level packaging structure, release artifacts, and public release state were not changed. Internal modular source, test, and documentation files were added.
- No analytics, telemetry, tracking, remote config, or network behavior was added.
- Mendy assets were not deleted.

## Phase B Final QA Result

The automated and targeted packaged Phase B pass is complete. `docs/UI_REBRAND_QA.md` is the evidence record and distinguishes fresh passes from partial/carried-forward checks. The final status item, popover, row navigation, Open macMender action, and collapsed-sidebar recovery were inspected in the packaged app. Remaining manual work includes physical devices/gestures; minimum-size onboarding; full spoken VoiceOver and Full Keyboard Access; global accessibility-display toggles; large-text popover wrapping; direct Profiles light/dark and light Option+Tab inspection; final packaged reruns of the carried-forward Dock, keyboard/Escape, animation, and Advanced stateful checks; and optional GPU/Instruments profiling.
