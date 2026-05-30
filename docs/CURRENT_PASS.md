# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/thaw-menu-bar-rewrite`

## Implemented in This Pass

1. Mendy now uses canonical local state assets: greeting, happy, thinking, scanning, idle, sleeping, success, and error.
2. Mendy state rendering is centralized in `MendyMood` / `MendyAssets`, with Reduce Motion-aware crossfade and restrained per-state motion.
3. Common settings, sidebar, popover, and preview surfaces now share reusable Liquid Glass components.
4. Menu bar snapshot section bucketing and the scoped movement policy live in the `MacMenderMenuBarEngine` boundary, while `MenuBarScannerService` remains the app adapter.
5. The cursor policy is explicit: cursor warp/hide APIs are allowed only inside the scoped Thaw-style `MenuBarItemMover` movement guard, not in reveal, activation, Dock/window, or UI paths.
6. Dock previews now pass bundle/PID-aware Dock identity into the switcher when available, and window matching avoids reusing one CG window for multiple AX windows.
7. Window activation now tries to unminimize, raise, and focus the selected AX window before activating the owning app.

## Still Known or Unverified

1. Full Thaw parity is not claimed. Side-by-side discovery, hide/reveal, Always Hidden, drag/reorder, secondary bar, pointer stability, and multi-display/manual Space testing are still required.
2. The existing `script/build_and_run.sh --verify` path creates `dist/macMender.app/Contents/XPCServices/MacMenderMenuBarItemService.xpc`, but helper launch/connect behavior and Thaw side-by-side source-PID parity remain unverified.
3. DockDoor parity is not claimed. Dock preview lifetime, jank, browser multi-window behavior, and neighboring Dock item mismatches still need a dedicated DockDoor pass.
4. Visual inspection of Mendy rendering, settings Liquid Glass, menu bar icon/popover, menu bar hide/reveal, and Dock/window behavior is still required on a launched app.
5. Mos-style scrolling, MiddleClick, and Dock tuning were intentionally not expanded in this pass.

## Verification Run

- `swift build`
- `swift test`
- `script/build_and_run.sh --verify` launched `dist/macMender.app` and confirmed a running `macMender` process.

Manual launch and UI verification should follow `docs/MANUAL_QA.md` and the menu bar QA scripts before release claims.
