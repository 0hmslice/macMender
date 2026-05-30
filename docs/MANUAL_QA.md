# Manual QA

Use this file for verification that cannot be proven by `swift build` or `swift test`.

## Current Pass Checklist

- Launch the built app and inspect onboarding, Preferences, Menu Bar, Dock & Windows, Privacy, and Profiles for Mendy state rendering.
- Confirm Mendy uses the local PNG state assets and respects Reduce Motion with simplified motion.
- Inspect the menu bar status item and popover. Confirm the status icon still opens the popover and the popover uses readable Liquid Glass styling.
- Inspect settings surfaces for readable Liquid Glass in light and dark appearances.
- Run `docs/MENU_BAR_SMOKE_TEST_SCRIPT.md` and `docs/MENU_BAR_MANUAL_TEST_CHECKLIST.md` before claiming Thaw/Ice parity.
- Confirm menu bar hide/reveal, Always Hidden, secondary bar, spacing, pointer coordinate stability, and Stats or another multi-icon app side by side with Thaw.
- Record whether `dist/macMender.app/Contents/XPCServices/MacMenderMenuBarItemService.xpc` exists. The current build script can create it, but helper launch/connect behavior still needs Console and source-PID validation.
- Verify Dock preview hover on several Dock items. The current pass improves bundle/PID identity matching but does not claim DockDoor parity.
- Verify browser multi-window previews with at least Safari, Chrome, or another browser with multiple titled windows.
- Verify Option+Tab and mouse-click activation on normal, minimized, and browser windows.

## Not Verified by This Agent Run

- `script/build_and_run.sh --verify` launched the app and confirmed a running process, but a visual UI pass was not completed in this implementation run.
- Real menu bar physical movement, hide/reveal, and pointer coordinate stability require local interactive testing.
- Thaw side-by-side parity was not completed.
- DockDoor-style preview lifetime, dismissal, animation, and browser thumbnail parity were not completed.
