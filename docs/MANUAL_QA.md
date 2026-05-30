# Manual QA

Use this file for verification that cannot be proven by `swift build` or `swift test`.

## Current Pass Checklist

- Launch the built app and inspect onboarding, Preferences, Menu Bar, Dock & Windows, Privacy, and Profiles for enlarged Mendy state rendering.
- Confirm Mendy uses the local PNG state assets, is recognizable at hero/panel/compact sizes, and respects Reduce Motion with simplified motion.
- Inspect the menu bar status item and popover. Confirm the status icon still opens the popover and the popover uses readable Liquid Glass styling.
- Inspect settings surfaces, Option+Tab, and Dock preview panels for readable Liquid Glass in light and dark appearances.
- Run `docs/MENU_BAR_SMOKE_TEST_SCRIPT.md` and `docs/MENU_BAR_MANUAL_TEST_CHECKLIST.md` before claiming Thaw/Ice parity.
- Confirm menu bar hide/reveal, Always Hidden, secondary bar, spacing, pointer coordinate stability, and Stats or another multi-icon app side by side with Thaw.
- Confirm cross-lane menu-bar chip drops do not show stale optimistic row state. After a drop, the lane should update only from live WindowServer refresh or Scan Now.
- Record whether `dist/macMender.app/Contents/XPCServices/MacMenderMenuBarItemService.xpc` exists. The current build script can create it, but helper launch/connect behavior still needs Console and source-PID validation.
- Verify Dock preview hover on several Dock items, especially adjacent apps such as Messages/Mail. Previews should appear only for bundle/PID-resolved Dock items and should not use title-only fallback.
- Verify browser multi-window previews with at least Safari, Chrome, or another browser with multiple titled windows.
- Verify Option+Tab and mouse-click activation on normal, minimized, and browser windows.

## Not Verified by This Agent Run

- Visual UI inspection of this direct-repair pass was not completed by the agent.
- Real menu bar physical movement, hide/reveal, and pointer coordinate stability require local interactive testing.
- Thaw side-by-side parity was not completed.
- DockDoor-style preview lifetime, dismissal, animation, and browser thumbnail parity were not completed.
