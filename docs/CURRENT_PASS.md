# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/thaw-direct-port-repair`

## Implemented in This Pass

1. Mendy remains on canonical local PNG state assets and now renders larger, more recognizable state art across onboarding, settings, popover, menu-bar, Dock, profiles, privacy, and secondary-bar surfaces.
2. Mendy motion is stronger but still restrained: less image padding, clearer float/pulse/bounce/shake states, and the existing Reduce Motion path remains in place.
3. Liquid Glass preview styling is stronger and reusable: preview surfaces now get heavier highlight/stroke/shadow treatment, and Option+Tab / Dock preview cards share the same glass card treatment.
4. Menu bar runtime work is now serialized through `MenuBarRuntimeOperationGate`, matching Thaw's rule that physical restore/move/reconcile work must not overlap while WindowServer frames are settling.
5. `MenuBarScannerService` now publishes `MacMenderMenuBarEngine` snapshots/status from live detected items while preserving live WindowServer section/order as display truth.
6. The menu-bar layout UI no longer performs optimistic cross-lane pending row moves after drop. It keeps drag feedback while dragging, then waits for the live WindowServer refresh.
7. The cursor policy remains explicit: cursor warp/hide APIs are allowed only inside the scoped Thaw-style `MenuBarItemMover` movement guard, not in reveal, activation, Dock/window, or UI paths.
8. Dock previews now require bundle/PID-resolved Dock identity and prefer exact/nearest Dock hit frames to reduce wrong-neighbor previews.

## Still Known or Unverified

1. Full Thaw parity is not claimed. Side-by-side discovery, hide/reveal, Always Hidden, drag/reorder, secondary bar, pointer stability, and multi-display/manual Space testing are still required.
2. The existing `script/build_and_run.sh --verify` path creates `dist/macMender.app/Contents/XPCServices/MacMenderMenuBarItemService.xpc`, but helper launch/connect behavior and Thaw side-by-side source-PID parity remain unverified.
3. DockDoor parity is not claimed. This pass only gates low-confidence Dock previews and tightens hit testing; preview lifetime, browser multi-window behavior, animations, and full DockDoor semantics still need a dedicated pass.
4. Visual inspection of enlarged Mendy rendering, settings Liquid Glass, menu bar icon/popover, menu bar hide/reveal/move, and Dock/window behavior is still required on a launched app.
5. Mos-style scrolling, MiddleClick, and Dock tuning were intentionally not expanded in this pass.

## Verification Run

- `swift build`
- `swift test`
- `script/build_and_run.sh --verify` launched `dist/macMender.app` and confirmed a running `macMender` process.

Manual launch and UI verification should follow `docs/MANUAL_QA.md` and the menu bar QA scripts before release claims.
