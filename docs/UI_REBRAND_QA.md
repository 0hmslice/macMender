# macMender Phase B UI Rebrand QA

Final verification record for the packaged UI rebrand. `Partial` means the automated or visual portion passed but a named carried-forward, physical, spoken-VoiceOver, global-accessibility, or screen-capture check remains.

## Run Metadata

- Overall status: **Automated and targeted packaged pass with disclosed manual residuals and one product gap**
- Branch: `codex/macos27-ui-rebrand`
- Presentation milestone: `b4c2707` (`Restyle onboarding popover and overlays`)
- Final QA milestone: `Complete accessibility and performance QA` (the commit containing this record)
- Date: 2026-07-24, America/Toronto
- Tester: Codex, using packaged-app Computer Use, source audit, and shell measurements
- macOS: 27.0, build `26A5388g`, arm64
- Xcode: 27.0 (`27A5228h`)
- Swift: Apple Swift 6.4 (`swiftlang-6.4.0.27.1 clang-2100.3.27.1`)
- Initial and final live config SHA-256: `2b219eab20ea6d00912a67cdfbee03f99bfd8d25be31fbb296df88a43d1960c6`
- Initial and final spacing state: current-host `NSStatusItemSpacing=0` and `NSStatusItemSelectionPadding=0`; both any-host/global keys absent

## Build, Test, and Package Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| `swift build` | Pass | Xcode-beta command-local developer directory; final accessibility sources compiled. |
| `swift test` | Pass | 103 tests in 11 suites after the quick-controls and Strip-layout follow-up. |
| `script/build_and_run.sh --verify` | Pass | Final packaged binary rebuilt, re-signed, and launched from `dist/macMender.app`. |
| Packaged launch/preferences window | Pass | Overview appeared and exposed the complete native AX tree. Exact cold timing was not isolated from automation; practical launches remained within the approximately one-second automation yield. |
| Status item | Pass | Packaged MenuBarAgent inspection confirmed the authored MacBook-and-stitches template glyph, successful click handling, and popover presentation. |

## Product-Area Verification

| Area | Result / evidence |
| --- | --- |
| App shell | Pass — native sidebar selection, toolbar profile picker, page routing, quiet semantic surfaces, and no routine mascot header/service block. |
| Onboarding | Pass at the intended 980×680 size, with a minimum-size residual — isolated-home QA covered all six steps, direct native rail selection, Back/Continue, permission refresh, scrolling drag guidance, privacy disclosure, Finish/Open, and Skip. Welcome/Finish are the only Mendy steps. Non-granted dual permission actions were statically verified because this bundle already has permission grants. |
| Overview | Pass — accurate profile and four feature summaries; card actions and AX labels present. |
| General | Pass — app-wide Launch at Login and Dock-icon controls render with current state; service bindings are unchanged from Phase A. |
| Input | Pass with hardware residual — scrolling, device separation, app overrides, sliders, and Three-Finger Tap render and respond. AX labels now include axis/device/app context and the response preview exposes a value and hint. Physical gestures remain manual. |
| Dock & Windows | Partial / carried-forward runtime evidence — all three tabs, settings, readback, discovery refresh, diagnostics, and the final visual overlay passed. Runtime identity/filtering/activation paths are unchanged and their tests pass, but the complete packaged matrix and physical secondary-click were not rerun after the presentation changes. |
| Menu Bar Spacing | Pass with documented OS limitation — focused UI, presets, slider, Apply/Reset state, and exact-build copy passed. Phase A's controlled matrix remains authoritative; Phase B did not rewrite preferences. |
| Profiles | Partial — native Table, selection without implicit activation, Make Active, Create, and Delete wiring remain present and the AX tree is complete. macOS 27 screen capture privacy-redacts this page while a text field is present, limiting visual automation. Rename and Duplicate are not implemented. |
| Privacy | Pass — live permission states, reasons, settings actions, separate gesture runtime state, refresh, and local-data disclosure are present. |
| Advanced | Partial / carried-forward evidence — status refresh produced `Updated just now`; save/export/import/show-in-Finder/Safe Mode/Dock refresh/disclosures/reset actions retain the audited Phase A closures. Stateful import/export and reset were not repeated against the live config in the final rebranded package. |
| Status-item popover | Pass with large-text/VoiceOver residual — packaged visual, accessibility, and interaction inspection confirmed four native quick toggles in one trailing alignment column, always-visible Open macMender and Quit, and no healthy-state prose, green checkmark capsules, profile filler, or Mendy. The quick controls were toggled off/on and restored. |
| Window Switcher Strip | Pass with final physical-keyboard residual — packaged `Test Switcher` displayed six live window previews in one horizontally scrollable native-style row with a strong selected border and selected window/app label. Pure sizing tests cover viewport bounds and minimum thumbnail sizing. Existing keyboard routing/activation tests pass; a physical Option-Tab visual cycle remains manual. |

Profiles supports create, select, Make Active, and delete. Rename and Duplicate remain an explicit Phase B implementation gap; no behavior was invented during a visual-only pass.

## Dock Preview and Option+Tab Regression Matrix

| Check | Result / evidence |
| --- | --- |
| Identity, adjacent item, Finder fake filtering, real Finder, browser windows, and macMender self-preview | Partial / carried-forward evidence — Phase A packaged matrix plus unchanged-service hard-boundary audit and passing discovery tests; the full matrix was not rerun after the presentation-only changes. |
| Context-menu suppression/recovery | Partial / carried-forward evidence — passed in Phase A and unit tests; physical secondary-click and a final packaged rerun remain manual. |
| Option+Tab overlay | Pass — final redesigned overlay showed seven real windows with thumbnails/fallbacks, one glass surface, semantic cards, visible Selected badge/border, and no selection magnification. |
| Mouse selection/activation | Pass — clicking the selected Brave card activated the captured Brave window and dismissed the overlay. |
| Keyboard cycle/commit and Escape routing | Partial / carried-forward evidence — passed in unchanged runtime tests and Phase A packaged QA; final synthetic Escape delivery to the non-activating panel was inconclusive. |
| Preview animation and linger | Partial / carried-forward evidence — passed in Phase A and unchanged runtime tests; the final sample could not be captured before automatic dismissal. |

## Appearance and Accessibility

| Check | Result / evidence |
| --- | --- |
| Dark appearance | Partial — captured routine pages, onboarding, Option+Tab, and the final aligned quick-control popover passed. Profiles was AX-verifiable but screen-capture-redacted. |
| Light appearance | Partial — captured routine pages passed using a temporary ad-hoc QA copy forced to Aqua. Profiles was AX-verifiable but screen-capture-redacted; final popover and Option+Tab light capture remain manual. |
| VoiceOver semantics | Pass for automated AX inspection: contextual Input labels/values/hints, native onboarding selected rows, status values, and overlay selected traits. Full spoken VoiceOver reading-order QA remains manual. |
| Keyboard/focus | Partial — native sidebar and onboarding rail keyboard navigation passed; complete Full Keyboard Access traversal remains manual. |
| Increase Contrast / Show Borders / Differentiate Without Color | Code and contrast audit pass — status text is semantic primary text, hue remains redundant in symbols/backgrounds/borders, strong borders honor contrast settings, and onboarding has native selected semantics plus a checkmark. System Settings' Accessibility pane repeatedly closed the Computer Use pipe, so global-mode visual confirmation remains manual. |
| Reduce Transparency | Code audit pass — glass/content surfaces have semantic opaque fallbacks. Final global toggle visual confirmation remains manual. |
| Reduce Motion | Code audit pass — active transitions use nil/reduced paths and no rebrand-added repeat-forever animation or view timer was found. The existing `DockHoverService` fallback timer predates Phase B and is unchanged. Final global toggle interaction remains manual. |
| Minimum size / large text | Standard 980×680 onboarding and scrollable permission layout passed. Minimum-practical-size onboarding remains manual. The compact 304×274 quick-control popover uses short labels and native switches; unusually large accessibility text and spoken ordering remain manual. |

## Performance

- Clean final packaged Overview: 0.0% CPU; `top` reported approximately 51–53 MB.
- Page sweep after settling: Overview 0.0%/53 MB, General 0.0%/58 MB, Menu Bar Spacing 0.0%/67 MB, Input 0.0%/95 MB, Dock & Windows 0.0%/93 MB, Profiles 0.0%/84 MB after one transient 0.2% sample, Privacy 0.0%/81 MB, Advanced 0.0%/82 MB.
- Earlier Phase B packaged window-closed sample: 0.0% CPU and approximately 62 MB.
- No rebrand-added `TimelineView`, sustained animation, view timer, or rendering/update loop was found. The existing 1.25-second `DockHoverService` fallback timer predates Phase B and is unchanged. The switcher's per-card icon lookup remains finite; profile it only if a future trace shows open-time churn.
- Final popover-open CPU and a dedicated GPU/Instruments trace remain manual. Phase A measured the unchanged popover host at 0.0% CPU.

## macOS 27 Compatibility Summary

- Tested: macOS 27.0 build `26A5388g` (Developer Beta 4), arm64.
- Verified classification: Apple-item frames found in the `MenuBarAgent` accessibility tree did not change when the legacy paired current-host spacing preferences were varied on this beta. The likely explanation is that this hosting/layout path does not consume those keys, but Apple has not documented that as the cause. No replacement domain or safe confirmed refresh host was found.
- Before/after mechanism: earlier macOS retains paired current-host writes plus Control Center refresh. Exact Beta 4 writes/verifies the paired values for AppKit compatibility, updates macMender's own item, performs no ineffective host restart, and reports `Unsupported on this beta` for Apple items.
- Apple/system items: unchanged at tested values `0`, `4`, `8`, `16`, `24`, and `32`.
- Application-owned AppKit probe: a freshly created local probe item honored the values. Unrelated third-party items were not comprehensively verified; they remain unconfirmed and may require recreation or relaunch.
- macMender item: synchronized across the full range and remained present; final state restored to explicit `0/0`.
- SystemUIServer was not restarted, so no claim is made about it. Other macOS 27 builds remain unconfirmed until measured.

## Final Handoff

1. macOS 27 build tested: 27.0 (`26A5388g`).
2. Menu Bar Spacing root cause/classification: measured Apple-item frames in the observed MenuBarAgent tree did not respond to the legacy paired keys on this beta; that hosting/layout path not consuming the keys is an evidence-based inference, not an Apple-documented cause.
3. Mechanism: verified paired current-host preferences retained for AppKit; exact-beta host restart removed; honest result mapping added.
4. System-item result: unsupported/unchanged on this beta.
5. Third-party result: a fresh application-owned AppKit probe responded; unrelated third-party items remain unconfirmed and may need recreation or relaunch.
6. macMender item result: synchronized and present.
7. Beta limitations: measured Apple-item frames did not respond to the keys on this build; SystemUIServer was not restarted; other macOS 27 builds are unconfirmed.
8. Regression result: build/tests/package and targeted packaged UI pass; manual residuals are listed below.
9. Design research: `docs/UI_REBRAND_RESEARCH.md`.
10. Visual principles: native, calm, precise, restrained, semantic, efficient, accessible, with small interaction-led whimsy.
11. Mendy: retired from routine UI, app icon, and status item; retained only in onboarding Welcome/Finish, preserved assets, and optional credits/easter-egg scope.
12. Page changes: native shell/forms/tables, concise status-led Overview, device-clear Input, focused spacing utility, separated Dock areas, permission/configuration forms, compact onboarding/popover, consistent overlays.
13. Accessibility: contrast blockers and ambiguous labels fixed; remaining global-mode/spoken checks are manual.
14. Performance: 0.0% settled CPU on every page, 51–95 MB `top` memory through the final sweep, and no rebrand-added sustained render/update loop.
15. Files changed: see the Phase A and Phase B commits; public/top-level packaging structure is unchanged.
16. Commits: listed in the final response; no push.
17. Manual QA: physical gestures/devices/Dock secondary-click; minimum-size onboarding; direct Profiles light/dark and light-appearance popover/overlay inspection; full spoken VoiceOver/Full Keyboard Access; global accessibility toggles; final packaged reruns of the carried-forward Dock/keyboard/animation and Advanced stateful checks; and a dedicated GPU trace if desired.
18. Next publishing prompt: `Review codex/macos27-ui-rebrand against codex/macos27-compatibility, run the remaining manual hardware/accessibility checks in docs/UI_REBRAND_QA.md, then—only if they pass—push codex/macos27-ui-rebrand and open a pull request. Do not publish a release or modify release artifacts.`

## Residual Manual/Hardware Checks

- Physical Three-Finger Tap and external-mouse versus built-in-trackpad scrolling feel.
- Magic Mouse / Magic Trackpad-specific device-rule behavior.
- Physical secondary-click Dock context menu while a preview is visible.
- Final packaged rerun of the carried-forward Dock identity/filtering matrix, context suppression/recovery, keyboard cycle/commit, Escape routing, and preview animation/linger checks.
- Final packaged stateful Advanced import/export/invalid-import/reset-onboarding checks using a disposable configuration.
- Redesigned onboarding at the minimum practical window size, including the rail, dual permission actions, drag guide, numbered instructions, and footer.
- Full spoken VoiceOver and Full Keyboard Access traversal.
- Global Increase Contrast, Show Borders, Differentiate Without Color, Reduce Transparency, and Reduce Motion visual pass; the System Settings pane was not automatable without losing the Computer Use connection.
- Final status-item popover visual/large-text interaction and popover-open CPU.
- Profiles visual confirmation in light and dark appearance outside ScreenCaptureKit's macOS 27 privacy redaction, plus a light-appearance Option+Tab capture.
- Optional dedicated GPU/Instruments trace and subjective cursor/beachball check.

No push, release, publishing action, or release-artifact change was performed.
