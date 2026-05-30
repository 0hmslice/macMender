# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/thaw-runtime-transplant`

## Implemented in This Pass

1. Physical menu-bar hide/reorder/move operations are disabled. The current partial macMender mover is not Thaw-equivalent and is bypassed instead of being patched again.
2. Settings > Menu Bar is now discovery-only for physical layout. It shows a clear disabled banner and does not offer working drag/drop or section movement controls while the real Thaw runtime is absent.
3. `MenuBarScannerService` reports movement disabled and refuses reveal, hide, reconcile, user-item move, and Mendy status-item move requests.
4. Mendy renders without hard square avatar containers by default, uses larger hero/overview sizes, and relies on state-colored glow/shadow plus local PNG state assets.
5. Liquid Glass surfaces now use native `glassEffect` on macOS 26 when available, with the existing layered material fallback for older runtimes.
6. Option+Tab and Dock preview panels are wrapped in a `GlassEffectContainer` where available and keep the stricter preview glass treatment.
7. Dock previews retain the strict high-confidence rule: bundle/PID identity is required, and title-only neighboring previews are suppressed.

## Still Known or Unverified

1. A real Thaw runtime transplant is not complete. Required missing pieces include Thaw's full `MenuBarItemManager`, `HIDEventManager`, `EventTap`, `ControlItem`, `MenuBarSection`, `LayoutSolver`, `LayoutReconciler`, `PendingLedger`, `IceBar/LayoutBar`, and exact XPC request/response service boundary.
2. The existing `script/build_and_run.sh --verify` path creates `dist/macMender.app/Contents/XPCServices/MacMenderMenuBarItemService.xpc`, but helper launch/connect behavior and Thaw side-by-side source-PID parity remain unverified.
3. DockDoor parity is not claimed. This pass only keeps high-confidence Dock preview gating; preview lifetime, browser multi-window behavior, animations, and full DockDoor semantics still need a dedicated pass.
4. Visual inspection of Mendy rendering, settings Liquid Glass, menu bar discovery disabled state, Option+Tab glass, and Dock adjacent-hover behavior is still required on a launched app.
5. Mos-style scrolling, MiddleClick, and Dock tuning were intentionally not expanded in this pass.

## Verification Run

- `swift build`
- `swift test`
- `script/build_and_run.sh --verify` launched `dist/macMender.app` and confirmed a running `macMender` process.

Manual launch and UI verification should follow `docs/MANUAL_QA.md` and the menu bar QA scripts before release claims.
