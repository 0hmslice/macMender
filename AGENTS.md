# AGENTS.md

## Project

macMender is a native macOS 26+ Swift/SwiftUI/AppKit utility app.

The app should feel like a first-party macOS utility with heavy Liquid Glass styling, restrained playful motion, and a state-driven guide mascot named Mendy.

The most complete working copy is expected to be:

`/Users/ryan/Documents/macMender`

## Product priorities

Primary priority:
1. Thaw/Ice-grade menu bar management.

Secondary priorities:
2. DockDoor-style Dock previews and window switching.
3. Mendy state system.
4. Liquid Glass visual system.
5. Smooth scrolling, middle-click, and Dock tuning as later subsystems.

Do not attempt to fully complete every subsystem in one pass unless explicitly asked.

## Hard rules

- Do not fake parity.
- Do not claim a feature works unless implemented and verified.
- Do not claim a build/test passed unless it actually ran.
- Do not bury private API usage.
- Do not add analytics, telemetry, remote config, tracking, or hidden network behavior.
- Do not copy upstream branding, icons, mascots, or marketing copy.
- Use only local branding assets.
- Preserve attribution and license notices for copied or ported upstream code.
- Do not create giant merged files.
- Keep code modular.
- Do not change signing, bundle identifier, entitlements, or Info.plist unless clearly required and explained.
- Do not push, merge, delete branches, or rewrite Git history unless explicitly told.

## Local assets

Use only these local identity assets:

- `AppIcon.icns`
- `macos_menubar_robot_icon_assets/`
- `Mendy/*.png`

Expected Mendy states:

- greeting
- happy
- thinking
- scanning
- idle
- sleeping
- success
- error

Mendy must be state-driven, not scattered hard-coded image names.

## Mendy requirements

Build or preserve a reusable Mendy view system with:

- symbolic state API
- PNG asset loading from local Mendy assets
- crossfade between states
- idle breathing/float motion
- subtle thinking motion
- scanning pulse
- success bounce
- restrained error shake
- Reduce Motion support

Use Mendy in onboarding, permissions, empty states, success/error feedback, and selective guidance moments.

Do not make Mendy constant visual noise.

## Liquid Glass requirements

Build reusable components instead of one-off styling:

- glass window background
- glass sidebar
- glass cards/panels
- glass settings rows
- glass buttons
- motion helpers
- readable light/dark behavior

Apply to onboarding, settings, menu bar settings, Mendy panels, and preview surfaces where safe.

## Menu bar management

Treat this as the primary subsystem.

Use Thaw/Ice as the main implementation reference.

Implement toward:

- visible items
- hidden items
- always hidden items
- overflow model
- hover reveal
- click reveal
- scroll reveal
- auto-rehide
- item discovery
- search where practical
- settings controls
- honest disabled states for incomplete features

Do not claim drag-and-drop item movement, system item movement, multi-icon app handling, or private API behavior works unless verified.

## Dock/window previews

Use DockDoor as the main reference.

For Dock/window preview work, prioritize correctness over visuals:

- correct app/window identity
- no neighboring Dock item mismatch
- correct browser multi-window thumbnails
- reliable preview lifetime rules
- correct click activation
- correct keyboard activation
- Liquid Glass preview surfaces

Do not deeply rewrite this during a menu bar pass unless explicitly asked.

## Smooth scrolling, middle-click, and Dock tuning

These are later subsystems unless explicitly scoped.

If touched, document whether the implementation is:

- implemented
- experimental
- disabled
- deferred
- blocked by private APIs
- blocked by verification limits

## Git workflow

- Always run `git branch --show-current` and `git status` before editing.
- If the working tree has unexpected uncommitted changes, stop and report them.
- Stay on the current feature branch unless explicitly told otherwise.
- Commit after verified milestones when asked to manage Git.
- Use clear commit messages.
- Do not push unless explicitly told.
- Do not merge unless explicitly told.
- Do not delete branches unless explicitly told.

## Verification

During serious implementation passes, use this loop:

1. inspect
2. edit
3. build
4. test
5. launch if possible
6. inspect
7. fix
8. rebuild
9. retest
10. document

Run where applicable:

- `swift build`
- `swift test`
- app launch
- resource inspection for AppIcon, menu bar robot assets, and Mendy PNGs
- onboarding check
- settings check
- Mendy rendering check
- menu bar icon check
- menu bar reveal/hide check

If something cannot be verified, document it in `docs/MANUAL_QA.md`.

## Required docs

Maintain or create:

- `README.md`
- `THIRD_PARTY_NOTICES.md`
- `docs/ARCHITECTURE.md`
- `docs/MANUAL_QA.md`
- `docs/UPSTREAM_MAPPING.md`
- `docs/CURRENT_PASS.md`

## Final report format for major passes

Report:

1. Existing project state found
2. Branch and Git status
3. Chosen architecture
4. Upstream sources inspected
5. License/attribution corrections made
6. Local assets wired
7. Mendy status
8. Menu bar status
9. Liquid Glass status
10. Dock/window status
11. Build/test/launch results
12. Verification performed
13. Manual QA still required
14. Files changed
15. Commits created
16. Exact next best prompt
