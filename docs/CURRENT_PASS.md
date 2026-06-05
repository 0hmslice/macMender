# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/onboarding-redesign`

## Focus

This pass restores one limited menu bar spacing preference without restoring third-party Menu Bar management.

Menu Bar management is deferred for a future rebuild from scratch. The app still has its own macMender menu bar status item and popover for Settings, Permissions, and Quit. The restored spacing control only writes or resets the global menu bar item spacing defaults.

## Implemented

1. Dock preview animations now animate the content layer only and keep the panel frame stable.
2. Slide Up uses the Dock anchor direction for appear and matching dismiss motion.
3. Dismissal uses each animation style's reverse state instead of a shared stale transform.
4. Visible Dock preview animation styles are reduced to polished options: System, Fade, Scale, Slide Up, and None.
5. Legacy saved Glass Pop values map to System; legacy saved Genie values map to Scale.
6. Onboarding is a multi-step flow: Welcome, Input and Three-Finger Tap, Dock and Windows, Permissions, Local Privacy, and Finish.
7. Onboarding uses real Accessibility, Screen Recording, and Input Monitoring permission status.
8. Input Monitoring uses CoreGraphics listen-event access status and stays separate from gesture runtime state.
9. The drag-to-add Privacy & Security guide is retained with a one-shot, Reduce Motion-safe nudge.
10. Onboarding uses section-specific Mendy assets for Overview, Input, Dock & Windows, and Privacy steps.
11. Onboarding header height is reduced so the step content has more room.
12. The permission drag-to-add guide now uses an adaptive layout with stable fixed visual pieces and a compact fallback.
13. The macMender status-item popover shows a glanceable running state, one Permissions summary row, Three-Finger Tap, Dock previews, Window Switcher, Open macMender, and a low-priority Quit control.
14. The popover shows a Permissions action only when setup or permission review is useful.
15. The top-right profile switcher uses a single profile-oriented symbol and keeps the active profile name compact.
16. General includes a Menu Bar Spacing section with System Default, Compact, Comfortable, and Wide presets.
17. Menu Bar spacing writes only `NSStatusItemSpacing` and `NSStatusItemSelectionPadding` in the current-host global domain, and reset deletes those keys.

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
- Menu Bar spacing does not scan, identify, move, hide, reveal, reorder, group, or manage individual menu bar icons.
- Bundle identifier, signing identity selection, and entitlements were not changed.
- `docs/qa/screenshots` was not modified.

## Manual QA Required

Use `docs/MANUAL_QA.md`. Confirm General shows only the limited Menu Bar Spacing preference, reset to default is available, and no Menu Bar management UI is visible while the app’s own status item/popover still works.
