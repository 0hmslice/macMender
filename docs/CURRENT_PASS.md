# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/remove-menubar-and-polish-settings`

## Focus

This pass removes Menu Bar management from the current product, preserves packaged-app launch responsiveness, and polishes Overview, Input, Privacy, Advanced diagnostics, and section-specific Mendy usage.

Menu Bar management is deferred for a future rebuild from scratch. The app still has its own macMender menu bar status item and popover for Settings, Permissions, and Quit.

## Implemented

1. Removed the Menu Bar settings section, Overview setup card/chip, Overview service row, onboarding Menu Bar card, popover Menu Bar setup row, scanner service, menu-bar management source, Thaw-port engine target, menu-bar XPC helper target, and menu-bar feature tests.
2. Removed menu-bar scanner startup work from `AppModel`.
3. Removed the shell toolbar pause/refresh controls.
4. Added Overview `Three-Finger Tap` status beside Permissions, Window Switcher, and Dock Previews.
5. Added `General` for Launch at Login and Dock icon behavior.
6. Refocused Privacy around the local privacy promise, permissions, Mendy guidance, technical local details, and separate Input Monitoring permission versus gesture runtime state.
7. Kept reset/onboarding, Safe Mode, export, `Status Refresh`, and technical service status in Advanced.
8. Deferred runtime startup briefly until after the first preferences window appears.
9. Made new/default profiles use three-finger tap as middle click.
10. Wired user-provided section-specific Mendy assets for Overview, General, Input, Dock & Windows, Privacy, Advanced, and Profiles.

## Asset Folders

The root `Mendy/` folder is the source/reference folder for user-provided Mendy PNG assets. SwiftPM bundles runtime resources from `Sources/macMender/Resources/Mendy/`, so section assets are copied there with the same filenames and no generated replacements.

## Launch Notes

Baseline packaged launch before edits observed process start at about 0.14s and first accessibility-visible window at about 7.8s in one shell/UI-scripting run. The visible UI still showed Menu Bar management and floating pause/refresh controls.

The suspected launch blockers were synchronous first-appear runtime refresh plus menu-bar scanner work. This pass removes menu-bar scanning and defers runtime startup after the first window render path.

## Boundaries Preserved

- Dock preview identity matching was not changed.
- Title-only Dock preview eligibility was not reintroduced.
- Dock thumbnail capture/cache logic was not changed.
- Option+Tab activation/discovery logic was not changed.
- Scrolling and MiddleClick runtime behavior were not changed.
- Menu Bar management UI, scanner/runtime/mover, XPC/helper packaging, Command-drag setup, Mark to Review, hidden icon, Show/Tuck, and physical movement copy were not restored.
- Bundle identifier, signing identity selection, and entitlements were not changed.
- `docs/qa/screenshots` was not modified.

## Manual QA Required

Use `docs/MANUAL_QA.md`. Confirm no Menu Bar management UI is visible, while the app’s own status item/popover still works.
