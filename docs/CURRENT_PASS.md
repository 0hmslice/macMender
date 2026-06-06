# Current macMender Pass

Most complete working copy:
`/Users/ryan/Documents/macMender`

Branch:
`codex/profile-state-repair`

## Focus

This pass repairs profile state correctness before public GitHub publishing. The selected profile must be the source of truth for profile-specific settings shown in Overview, Input, Dock & Windows, Profiles, and the status-item popover, and switching profiles must immediately reapply the selected profile's runtime settings.

Menu Bar management remains removed/deferred. The limited Menu Bar Spacing page remains app-wide and only reads, writes, or resets the global menu bar item spacing defaults.

## Profile State Source of Truth

- `AppConfig.activeProfileID` is the selected profile identifier.
- `AppConfig.profiles` owns the saved profile list.
- `AppConfig.activeProfile` is the single model-level lookup for the selected profile.
- `ProfileStore.activeProfile` and `AppModel.activeProfile` delegate to `AppConfig.activeProfile`.
- Profile switching calls `AppModel.setActiveProfile(_:)`, which updates the selected profile and reapplies runtime services without changing Dock preview identity, thumbnail capture/cache, or Option+Tab discovery/activation logic.
- Profile edits call `AppModel.updateActiveProfile(_:)`, which writes to the selected saved profile and reapplies only the changed runtime areas.

## Settings Ownership

Profile-specific:

- Input and scrolling behavior.
- Three-Finger Tap / Middle Click behavior.
- Dock preview behavior, animation, hover, linger, and visual settings.
- Window Switcher behavior and visual settings.
- Dock profile values that require explicit Apply to the system Dock.

App-wide:

- Launch at Login.
- Dock icon visibility.
- Onboarding completion.
- Safe Mode.
- Permission status.
- macMender status item behavior.
- Menu Bar Spacing.

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
16. Menu Bar Spacing is its own sidebar section, not part of General.
17. Menu Bar Spacing includes System Default, Compact, Comfortable, Wide, and Custom selections plus a precision slider.
18. Menu Bar spacing writes only `NSStatusItemSpacing` and `NSStatusItemSelectionPadding` in the current-host global domain, and reset deletes those keys.
19. Apply and Reset refresh Control Center only so menu bar icons can update without logout where macOS allows it.
20. App defaults stay at true System Default; macMender does not write spacing keys until the user applies a preset or custom value.
21. The macMender status item adapts its own length to match the effective spacing value while keeping the popover and status item identity intact.
22. Decoded/imported configs now repair empty or invalid profile selections to a real saved profile.
23. The top-right profile switcher uses live profile count and a stable toolbar slot so it appears immediately when multiple profiles exist.
24. The Profiles page labels the selected setup as Current Profile instead of implying the visible settings are always the default profile.
25. Menu Bar Spacing pending controls reload from app-wide stored behavior and do not follow profile switches.
26. Focused tests cover profile selection repair, switcher visibility, per-profile setting isolation, and app-wide Menu Bar Spacing behavior.

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
- Menu Bar spacing does not scan, identify, move, hide, reveal, reorder, group, relaunch, or manage individual menu bar icons.
- Some third-party status-item apps may need to refresh or relaunch before they reread the global spacing defaults; macMender does not relaunch them automatically.
- Bundle identifier, signing identity selection, and entitlements were not changed.
- `docs/qa/screenshots` was not modified.

## Manual QA Required

Use `docs/MANUAL_QA.md`. Confirm multiple profiles show the top-right profile switcher immediately, switching profiles updates visible profile-specific settings, app-wide settings do not change per profile, and no Menu Bar management UI is visible while the app’s own status item/popover still works.
