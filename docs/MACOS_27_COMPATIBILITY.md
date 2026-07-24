# macOS 27 Compatibility

This report records Phase A compatibility evidence for macOS 27. It distinguishes measured behavior from inference and keeps the developer diagnostics separate from the shipping menu bar spacing feature.

## Test Environment

- macOS: 27.0
- Build: `26A5388g`
- Kernel: Darwin 27.0.0, `xnu-13432.0.94.501.4~1/RELEASE_ARM64_T8112`
- Architecture: arm64
- Xcode: 27.0 (`27A5228h`)
- Swift: Apple Swift 6.4 (`swiftlang-6.4.0.27.1 clang-2100.3.27.1`)
- Swift target: `arm64-apple-macosx27.0.0`

The machine-wide selected developer directory is Command Line Tools. Builds in this pass use `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` without changing the user's global `xcode-select` setting.

## Untouched Baseline

Before compatibility edits:

- `swift build`: passed with Xcode 27 selected command-locally.
- `swift test`: 72 tests in 8 suites passed.
- `script/build_and_run.sh --verify`: passed.
- Packaged app: launched and exposed its Overview window in approximately 1.43 seconds, including automation overhead.
- Status item: present and opened the macMender popover.
- Idle with preferences open: 0.0% sampled CPU, approximately 55–56 MB resident memory.
- Idle with preferences closed: 0.0% sampled CPU, approximately 62 MB resident memory.
- Current-host `NSStatusItemSpacing`: present, integer `0`.
- Current-host `NSStatusItemSelectionPadding`: present, integer `0`.
- Any-host/global versions of both keys: absent.

The exact original preference state is therefore explicit `0/0`, not System Default. The controlled tests restored that state. Read-only backup copies were also saved under `/tmp/macmender-phase-a-originals.rHoey9/` for this local pass.

## Apple and Platform Research

Apple's public [`NSStatusBar`](https://developer.apple.com/documentation/appkit/nsstatusbar) documentation describes the supported API for application status items, but does not document either spacing key. The private keys remain an implementation detail.

Apple defines [`kCFPreferencesCurrentHost`](https://developer.apple.com/documentation/corefoundation/kcfpreferencescurrenthost) as the current-host scope. The existing private-key implementation uses [`CFPreferencesCopyValue`](https://developer.apple.com/documentation/corefoundation/cfpreferencescopyvalue%28_%3A_%3A_%3A_%3A%29) with `AnyApplication / CurrentUser / CurrentHost`. The controlled probe confirms that this tuple remains effective for newly created AppKit status items on the tested build. No evidence of a replacement domain for Apple/system items was found, but the test cannot prove that no separate domain exists.

A search of the [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes) found no spacing-key, MenuBarAgent, Control Center, or SystemUIServer migration guidance. This absence does not prove removal; it only means Apple has not published a workaround there.

Apple's [macOS 27 status-item forum thread](https://developer.apple.com/forums/thread/836113) records developer reports of nearby beta regressions. Apple DTS responded to the thread and requested a focused reproducible sample; the response does not establish a spacing-specific Apple diagnosis:

- `FB23329983`: hover and mouse-movement delivery.
- `FB23330269`: programmatic status-item button highlighting.
- `FB23349447`: status-item occlusion state.

No public Feedback number specifically for Apple/system-item spacing was found.

## Hosting Change on Build 26A5388g

Verified locally:

- `/System/Library/CoreServices/MenuBarAgent.app` declares a minimum system version of macOS 27.0 and is registered by a keep-alive launch agent.
- Its bundle registers the `com.apple.appkit.status-items` workspace and services for Control Center items and menu items.
- The diagnostic found `com.apple.menuextra.wifi`, `sound`, `battery`, `controlcenter`, and `clock` in `MenuBarAgent`'s Accessibility tree.
- Control Center and SystemUIServer were running, but the diagnostic returned no top-edge `AXMenuBarItem` records for either process.
- `CGWindowListCopyWindowInfo` exposed one WindowServer-owned `Menubar` window and did not expose individual system-item windows to this diagnostic.

This is corroborated by a community observation in the [Thaw macOS 27 tracker](https://github.com/stonerl/Thaw/issues/687#issuecomment-4653888697), which reports one menu-bar window from `CGSGetProcessMenuBarWindowList` and identifies MenuBarAgent as a likely new host. The local process, bundle, and Accessibility observations are verified. The conclusion that Apple moved system-item layout responsibility into a new MenuBarAgent path is an inference because Apple has not documented the internal architecture.

## Controlled Spacing Matrix

The developer-only probes are:

- `script/menu_bar_spacing_diagnostic.swift`: read-only preferences, known host processes, and top-edge AX/CG frames.
- `script/status_item_spacing_probe.swift`: briefly creates and removes two status items owned only by the probe process, then reports their frames. It does not inspect, click, move, hide, or relaunch another app.

Every write was guarded by restoration logic. Neither script is part of the SwiftPM app target.

### No refresh

System Default and explicit values `0`, `4`, `8`, `16`, `24`, and `32` were applied to both current-host keys and verified after each operation. System Default means that both keys are absent; it is not a numeric preset. Without a refresh, all selected existing-item frames remained unchanged:

| Item | Frame at 0 | Frame at 32 |
| --- | --- | --- |
| Wi-Fi | `x=1337, w=22` | `x=1337, w=22` |
| Sound | `x=1375, w=22` | `x=1375, w=22` |
| Battery | `x=1413, w=26` | `x=1413, w=26` |
| Control Center | `x=1535, w=26` | `x=1535, w=26` |
| Clock | `x=1573, w=113` | `x=1573, w=113` |
| Stats combined item | `x=927, w=265` | `x=927, w=265` |
| Existing macMender item | `x=1174, w=26` | `x=1174, w=26` |

Wi-Fi to Sound and Sound to Battery both retained 16-point visual gaps at every sampled state. Those system items share the same MenuBarAgent Accessibility tree, so their relative frames provide a useful comparison. The Stats and macMender Accessibility frames overlap in global coordinates; they are useful as within-item before/after indicators but are not reliable for measuring cross-process visual gaps.

### Freshly created AppKit probe items

A freshly launched probe process produced the following item widths. A consistent one-point asymmetry appeared between the two probe items at every value; the test did not establish its cause. Both item widths tracked the paired preference value.

| Stored state | Probe A width | Probe B width |
| --- | ---: | ---: |
| System Default | 32 | 31 |
| 0 | 16 | 15 |
| 4 | 20 | 19 |
| 8 | 24 | 23 |
| 16 | 32 | 31 |
| 24 | 40 | 39 |
| 32 | 48 | 47 |

This verifies that changing the paired current-host values affects freshly created application-owned AppKit probe-item frames on build `26A5388g`. Because both keys were assigned the same value in this matrix, the width results do not independently prove how `NSStatusItemSpacing` and `NSStatusItemSelectionPadding` each contribute to item width or inter-item layout.

### Host refreshes at explicit value 32

- Control Center restart at `32`: PID changed; every measured Apple, Stats, and macMender frame remained identical.
- MenuBarAgent restart at `32`: PID changed; every measured Apple, Stats, and macMender frame remained identical.
- SystemUIServer was not restarted. The diagnostic found no system-extra tree under that process on this build, and restarting the observed Accessibility host had already produced no change, so another system-process restart was not justified.

The MenuBarAgent restart was a one-time compatibility diagnostic against a private system service, not validation of a supported refresh API and not a recommended shipping action.

In the developer-only matrix, both keys were restored as present integers `0`, Control Center and MenuBarAgent were relaunched once at the restored state, and the original frames were confirmed.

## Compatibility Conclusion

Measured on macOS 27 Beta 4 build `26A5388g`:

- The existing `AnyApplication / CurrentUser / CurrentHost` tuple remains effective when the paired values are changed for newly created AppKit probe items.
- Fresh application-owned AppKit probe-item widths varied predictably across explicit paired values `0` through `32`; System Default produced the same widths as explicit `16` in this probe.
- The existing Stats and macMender item frames did not change from preference writes alone.
- Selected Apple/system item frames and gaps showed no observable change across the sampled states without a refresh.
- At explicit value `32`, restarting Control Center and MenuBarAgent did not change any selected Apple/system item frame or gap.
- SystemUIServer was not restarted, so this pass makes no measured claim about its effectiveness as a refresh mechanism.

The evidence is consistent with Apple/system items on this build using a MenuBarAgent-hosted layout path that no longer consumes the legacy private AppKit spacing preferences. That internal cause is an inference, not a documented Apple contract. Existing third-party apps may need to recreate their status item, potentially through a manual app relaunch, but that behavior was not verified for every app.

The shipping app must retain the preferences for AppKit compatibility, update only macMender's own status-item length after a verified write, never relaunch unrelated apps, and report the Apple-item limitation honestly. Apple/system-item spacing on exact build `26A5388g` can be classified as Unsupported on this beta; the spacing preference as a whole is not unsupported because freshly created application-owned AppKit probe items still respond. Later macOS 27 builds should remain unconfirmed until measured rather than inheriting a permanent unsupported claim.

## Packaged Compatibility Verification

The final packaged Phase A build passed `swift build`, 95 tests in 9 suites, and `script/build_and_run.sh --verify`.

- Apply at explicit `16` wrote and verified both current-host keys and produced a 40-point macMender Accessibility frame.
- Reset deleted both keys and retained the same measured 40-point frame, confirming the exact-build Default-equals-`16` relationship observed in the controlled AppKit probe.
- Restoring custom `0` wrote both keys as integer `0` and returned macMender to its expected 24-point post-fix frame.
- Apply and Reset left Control Center, MenuBarAgent, and SystemUIServer PIDs unchanged on build `26A5388g`.
- The packaged result copy reported `Unsupported on this beta` for custom spacing without claiming that Apple items updated. Reset reported that System Default was restored while retaining the Apple-item limitation in its detail.
- The original app config, current-host values, any-host/global absence, dark appearance, and accessibility-display preferences were restored after testing.

Fresh application-owned AppKit probe items are the verified compatibility evidence. No unrelated third-party application was automatically terminated or relaunched, and this pass does not generalize the probe result to every framework or application.

## Upstream Inspection and Licenses

No upstream code was copied. GPL projects were inspected only to understand behavior and compatibility.

| Project | License observed | Use in this pass |
| --- | --- | --- |
| [Thaw](https://github.com/stonerl/Thaw) | GPL-3.0 | Behavior and macOS 27 issue inspection at commit [`b32f660`](https://github.com/stonerl/Thaw/commit/b32f660b224961d9a172d5c7706665f18ef27ea8) only; no code copied. |
| [Ice](https://github.com/jordanbaird/Ice) | GPL-3.0 | Current-source comparison and inspection of an open, unmerged relaunch proposal only; no code copied. |
| [SaneBar](https://github.com/sane-apps/SaneBar) | MIT | Preference/refresh comparison only; no code copied. |
| [Clamper](https://github.com/validatedev/Clamper) | MIT | Preference/refresh comparison only; no code copied. |
| [BarTuner](https://github.com/s1xu/BarTuner) | MIT | Refresh comparison only; no code copied. |
| [TighterMenubar](https://github.com/vanja-ivancevic/TighterMenubar) | MIT text in README; no recognized standalone license file | Notification behavior comparison only; no code copied. |
| [MenuBarSpacer](https://github.com/Theo-Ghanem/MenuBarSpacer) | No detected license | Behavior inspection only; no code copied. |
| [thaw-problems](https://github.com/fleytman/thaw-problems) | No detected license | Relaunch-risk documentation only; no code copied. |
| [beyondthecode-bc/MenuBarSpacing](https://github.com/beyondthecode-bc/MenuBarSpacing) | Community repository materials are MIT; the distributed app is described as closed source | Metadata comparison only; no code copied. |
| [Sindre Sorhus Menu Bar Spacing](https://sindresorhus.com/menu-bar-spacing) | Application source/license not published | User-facing behavior documentation only. |

The inspected Thaw development source at commit `b32f660b224961d9a172d5c7706665f18ef27ea8` relaunches item-owning apps so those apps recreate their status items. An [open, unmerged Ice pull request](https://github.com/jordanbaird/Ice/pull/923) proposes restarting every item-owning app on Apply; this is not current or released Ice behavior. macMender will not adopt either approach because it can interrupt unrelated work and would violate this pass's narrow spacing boundary.
