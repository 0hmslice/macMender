# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/remove-menubar-and-polish-settings`

## Focus

This pass removes Menu Bar management from the current product, investigates packaged-app launch responsiveness, and reorganizes settings around normal user expectations.

Menu Bar management is deferred for a future rebuild from scratch. The app still has its own macMender menu bar status item and popover for Settings, Permissions, and Quit.

## Implemented

1. Removed the Menu Bar settings section, Overview setup card/chip, Overview service row, onboarding Menu Bar card, popover Menu Bar setup row, scanner service, menu-bar management source, Thaw-port engine target, menu-bar XPC helper target, and menu-bar feature tests.
2. Removed menu-bar scanner startup work from `AppModel`.
3. Removed the shell toolbar pause/refresh controls.
4. Added Overview `Status Refresh`, which updates permissions, login item status, Dock defaults, and active helper state without window discovery or thumbnail capture.
5. Added `General` for Launch at Login and Dock icon behavior.
6. Refocused Privacy around the local privacy promise, permissions, Mendy guidance, and technical local details.
7. Kept reset/onboarding, Safe Mode, export, and technical status in Advanced.
8. Deferred runtime startup briefly until after the first preferences window appears.

## Launch Notes

Baseline packaged launch before edits observed process start at about 0.14s and first accessibility-visible window at about 7.8s in one shell/UI-scripting run. The visible UI still showed Menu Bar management and floating pause/refresh controls.

The suspected launch blockers were synchronous first-appear runtime refresh plus menu-bar scanner work. This pass removes menu-bar scanning and defers runtime startup after the first window render path.

## Boundaries Preserved

- Dock preview identity matching was not changed.
- Title-only Dock preview eligibility was not reintroduced.
- Dock thumbnail capture/cache logic was not changed.
- Option+Tab activation/discovery logic was not changed.
- Scrolling and MiddleClick runtime behavior were not changed.
- Bundle identifier, signing identity selection, and entitlements were not changed.
- `docs/qa/screenshots` was not modified.

## Manual QA Required

Use `docs/MANUAL_QA.md`. Confirm no Menu Bar management UI is visible, while the app’s own status item/popover still works.
