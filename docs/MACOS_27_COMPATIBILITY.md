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

Apple defines [`kCFPreferencesCurrentHost`](https://developer.apple.com/documentation/corefoundation/kcfpreferencescurrenthost) as the current-host scope. The established lookup through [`CFPreferencesCopyValue`](https://developer.apple.com/documentation/corefoundation/cfpreferencescopyvalue%28_%3A_%3A_%3A_%3A%29) remains `AnyApplication / CurrentUser / CurrentHost`; no evidence of a replacement domain was found.

A search of the [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes) found no spacing-key, MenuBarAgent, Control Center, or SystemUIServer migration guidance. This absence does not prove removal; it only means Apple has not published a workaround there.

Apple's [macOS 27 status-item forum thread](https://developer.apple.com/forums/thread/836113) records nearby beta regressions acknowledged by Apple DTS:

- `FB23329983`: hover and mouse-movement delivery.
- `FB23330269`: programmatic status-item button highlighting.
- `FB23349447`: status-item occlusion state.

No public Feedback number specifically for Apple/system-item spacing was found.

## Hosting Change on Build 26A5388g

Verified locally:

- `/System/Library/CoreServices/MenuBarAgent.app` is a macOS 27-only, keep-alive launch agent.
- Its bundle registers the `com.apple.appkit.status-items` workspace and services for Control Center items and menu items.
- `MenuBarAgent` owns the Accessibility tree containing `com.apple.menuextra.wifi`, `sound`, `battery`, `controlcenter`, and `clock`.
- Control Center and SystemUIServer are running but expose no menu-bar-item Accessibility tree.
- Core Graphics exposes one composite WindowServer `Menubar` window rather than individual system-item windows.

This is corroborated by the [Thaw macOS 27 tracker](https://github.com/stonerl/Thaw/issues/687), which reports a single composite menu-bar window and the new host. The local process, bundle, and frame observations are verified; conclusions about Apple's internal implementation beyond those observations are inference.

## Controlled Spacing Matrix

The developer-only probes are:

- `script/menu_bar_spacing_diagnostic.swift`: read-only preferences, known host processes, and top-edge AX/CG frames.
- `script/status_item_spacing_probe.swift`: briefly creates and removes two status items owned only by the probe process, then reports their frames. It does not inspect, click, move, hide, or relaunch another app.

Every write was guarded by restoration logic. Neither script is part of the SwiftPM app target.

### No refresh

System Default and explicit values `0`, `4`, `8`, `16`, `24`, and `32` were written to both current-host keys and verified after each operation. Without a refresh, all observed frames remained unchanged:

| Item | Frame at 0 | Frame at 32 |
| --- | --- | --- |
| Wi-Fi | `x=1337, w=22` | `x=1337, w=22` |
| Sound | `x=1375, w=22` | `x=1375, w=22` |
| Battery | `x=1413, w=26` | `x=1413, w=26` |
| Control Center | `x=1535, w=26` | `x=1535, w=26` |
| Clock | `x=1573, w=113` | `x=1573, w=113` |
| Stats combined item | `x=927, w=265` | `x=927, w=265` |
| Existing macMender item | `x=1174, w=26` | `x=1174, w=26` |

Wi-Fi to Sound and Sound to Battery both retained 16-point visual gaps at every value.

### Recreated AppKit items

A freshly launched probe process produced the following item widths. The one-point difference between its two items is stable host rounding; both track the requested value.

| Stored state | Probe A width | Probe B width |
| --- | ---: | ---: |
| System Default | 32 | 31 |
| 0 | 16 | 15 |
| 4 | 20 | 19 |
| 8 | 24 | 23 |
| 16 | 32 | 31 |
| 24 | 40 | 39 |
| 32 | 48 | 47 |

This verifies that newly created third-party AppKit status items still read the two current-host keys on build `26A5388g`.

### Host refreshes at value 32

- Control Center restart: PID changed; every measured Apple, Stats, and macMender frame remained identical.
- MenuBarAgent restart: PID changed; every measured Apple, Stats, and macMender frame remained identical.
- SystemUIServer was not restarted. It exposes no system-extra tree on this build, and the actual host restart already produced no change, so another system-process restart was not justified.

After testing, both keys were restored as present integers `0`, Control Center and MenuBarAgent were relaunched once at the restored state, and the original frames were confirmed.

## Compatibility Conclusion

Verified on macOS 27 Beta 4 build `26A5388g`:

- The preference domain did not move.
- Fresh third-party AppKit status items still honor the keys.
- Existing third-party apps may require a manual relaunch to recreate their items.
- Apple/system menu extras ignore values from System Default through 32, even after the new host restarts.
- Restarting Control Center, MenuBarAgent, or SystemUIServer is not a reliable spacing refresh strategy for this build.

The shipping app must retain the preference for third-party compatibility, update only macMender's own item immediately, never relaunch unrelated apps, and report the Apple-item limitation honestly. Exact build `26A5388g` can be classified as Unsupported on this beta. Later macOS 27 builds should remain unconfirmed until measured rather than inheriting a permanent unsupported claim.

## Upstream Inspection and Licenses

No upstream code was copied. GPL projects were inspected only to understand behavior and compatibility.

| Project | License observed | Use in this pass |
| --- | --- | --- |
| [Thaw](https://github.com/stonerl/Thaw) | GPL-3.0 | Behavior and macOS 27 issue inspection only; no code copied. |
| [Ice](https://github.com/jordanbaird/Ice) | GPL-3.0 | Behavior and relaunch-risk inspection only; no code copied. |
| [SaneBar](https://github.com/sane-apps/SaneBar) | MIT | Preference/refresh comparison only; no code copied. |
| [Clamper](https://github.com/validatedev/Clamper) | MIT | Preference/refresh comparison only; no code copied. |
| [BarTuner](https://github.com/s1xu/BarTuner) | MIT | Refresh comparison only; no code copied. |
| [TighterMenubar](https://github.com/vanja-ivancevic/TighterMenubar) | MIT text in README; no recognized standalone license file | Notification behavior comparison only; no code copied. |
| [MenuBarSpacer](https://github.com/Theo-Ghanem/MenuBarSpacer) | No detected license | Behavior inspection only; no code copied. |
| [thaw-problems](https://github.com/fleytman/thaw-problems) | No detected license | Relaunch-risk documentation only; no code copied. |
| [beyondthecode/MenuBarSpacing](https://github.com/beyondthecode/MenuBarSpacing) | Repository MIT; distributed app described as closed source | Metadata comparison only; no code copied. |
| [Sindre Sorhus Menu Bar Spacing](https://sindresorhus.com/menu-bar-spacing) | Application source/license not published | User-facing behavior documentation only. |

Ice and Thaw relaunch item-owning apps so those apps recreate their status items. macMender will not adopt that approach because it can interrupt unrelated work and would violate this pass's narrow spacing boundary.
