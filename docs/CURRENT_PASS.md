# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/macos27-compatibility`

## Focus

This is Phase A of the current work: macOS 27 compatibility and full regression QA. Phase B, the visual rebrand, has not started and must remain separate from the compatibility commits.

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

## Untouched Baseline

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

## Post-Fix Verification Status

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
- Dock preview identity matching, Finder filtering, thumbnail capture/cache, Dock context-menu suppression, Option+Tab activation, and Escape routing were not changed.
- Input, scrolling, Three-Finger Tap, profiles, config import/export, permissions, and Dock preference behavior were not changed.
- Bundle identifier, signing, entitlements, repository structure, release artifacts, and public release state were not changed.
- No analytics, telemetry, tracking, remote config, or network behavior was added.
- Mendy assets were not deleted.

## Remaining Manual/Hardware QA

The packaged Phase A matrix is complete. The physical-device and subjective residuals are listed under `Remaining Manual/Hardware Checks` in `docs/MANUAL_QA.md`.
