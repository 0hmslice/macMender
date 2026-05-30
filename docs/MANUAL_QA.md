# Manual QA

Use this file for verification that cannot be proven by `swift build` or `swift test`.

## Current Pass Checklist

- Launch the built app and inspect onboarding, Preferences, Menu Bar, Dock & Windows, Privacy, and Profiles for enlarged Mendy state rendering.
- Confirm Mendy uses the local PNG state assets, is recognizable at hero/panel/compact sizes, and respects Reduce Motion with simplified motion.
- Inspect the menu bar status item and popover. Confirm the status icon still opens the popover and the popover uses readable Liquid Glass styling.
- Inspect settings surfaces, Option+Tab, and Dock preview panels for readable Liquid Glass in light and dark appearances.
- Confirm Settings > Menu Bar clearly states physical movement is disabled and does not present fake working hide/reorder controls.
- Confirm menu-bar discovery still lists detected items and fixed/read-only items honestly.
- Do not run hide/reveal, Always Hidden, secondary bar, or drag/reorder as working features in this pass. They are intentionally disabled until a real Thaw runtime transplant is implemented.
- Record whether `dist/macMender.app/Contents/XPCServices/MacMenderMenuBarItemService.xpc` exists. The current build script can create it, but helper launch/connect behavior still needs Console and source-PID validation.
- Verify Dock preview hover on several Dock items, especially adjacent apps such as Messages/Mail. Previews should appear only for bundle/PID-resolved Dock items and should not use title-only fallback.
- Verify browser multi-window previews with at least Safari, Chrome, or another browser with multiple titled windows.
- Verify Option+Tab and mouse-click activation on normal, minimized, and browser windows.

## Not Verified by This Agent Run

- Visual UI inspection of this direct-repair pass was not completed by the agent.
- Real menu bar physical movement, hide/reveal, and pointer coordinate stability are disabled, not verified.
- Thaw side-by-side parity was not completed; the next menu-bar pass must transplant the full runtime shape or keep these features disabled.
- DockDoor-style preview lifetime, dismissal, animation, and browser thumbnail parity were not completed.
