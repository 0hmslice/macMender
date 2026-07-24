# Upstream Mapping

## Current Active Upstream Dependencies

No active Menu Bar management upstream code is shipped in the current app.

The current app continues to use local Swift/AppKit/SwiftUI code plus the existing MultitouchSupport bridge for the MiddleClick subsystem.

## Historical Menu Bar References

Ice and Thaw research from earlier Menu Bar management work was moved to `docs/archive/menu-bar-removed-2026-06-02/`. Those notes are historical only.

Future Menu Bar work should start from a new design and verification plan instead of treating the archived code or docs as current product direction.

## macOS 27 Compatibility Research

The active Menu Bar Spacing compatibility research, measured behavior, source links, and license classifications are recorded in `docs/MACOS_27_COMPATIBILITY.md`.

No upstream source was copied for that work. GPL-3.0-licensed Ice and Thaw code was inspected only to understand behavior. The compatibility diagnostics and implementation are independent macMender code.

Research-only references relevant to this pass:

| Upstream | License/status | How it was used |
| --- | --- | --- |
| [Thaw](https://github.com/stonerl/Thaw) | GPL-3.0 | Development source at commit [`b32f660`](https://github.com/stonerl/Thaw/commit/b32f660b224961d9a172d5c7706665f18ef27ea8) and macOS 27 reports were inspected for behavior only. A [community comment](https://github.com/stonerl/Thaw/issues/687#issuecomment-4653888697) reports the composite menu-bar window and new MenuBarAgent process; another [community comment](https://github.com/stonerl/Thaw/issues/687#issuecomment-4660610664) reports third-party-only spacing on an earlier macOS 27 beta. Neither comment is authoritative Apple documentation. |
| [Ice](https://github.com/jordanbaird/Ice) | GPL-3.0 | Current source was inspected for comparison. [Pull request 923](https://github.com/jordanbaird/Ice/pull/923), which proposes restarting every item-owning app on Apply, is open and unmerged; it is not current or released Ice behavior. |
| [SaneBar](https://github.com/sane-apps/SaneBar), [Clamper](https://github.com/validatedev/Clamper), and [BarTuner](https://github.com/s1xu/BarTuner) | MIT | Preference and refresh approaches were compared; no code was copied. |
| [beyondthecode-bc/MenuBarSpacing](https://github.com/beyondthecode-bc/MenuBarSpacing) | Community repository materials are MIT; distributed app described as closed source | Metadata and user-facing behavior were compared; no application source was available or copied. |

The inspected Thaw implementation at commit `b32f660b224961d9a172d5c7706665f18ef27ea8` relaunches item-owning apps. The Ice behavior discussed above exists only in the open pull request. macMender intentionally does neither: it updates only its own status-item length and does not terminate or relaunch unrelated applications.
