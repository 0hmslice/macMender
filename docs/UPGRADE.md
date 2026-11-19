# macMender utility upgrade

Research checked September 23, 2026. The v0.10.0 public preview builds on v0.9.0 and keeps existing profiles and direction rules. Its download is signed with an Apple Development certificate and is not notarized.

## Comparison and decisions

| Utility | Useful reference | macMender decision |
| --- | --- | --- |
| [LinearMouse](https://linearmouse.app/en/) | Profiles vary by device, app, and display; independent mouse and trackpad scrolling. | Keep profile-owned rules; add an explicit native-scroll bypass and preserve rules/direction when changing presets. Physical device identity needs a separate HID implementation. |
| [BetterMouse](https://better-mouse.com/) | Per-app exceptions and configurable scrolling; vendor hardware and button controls. | Add an application picker for apps that are not running. Fix axis control precedence and cancel scroll tails on pause/input changes. Vendor-specific hardware controls are outside this upgrade. |
| [AltTab](https://alt-tab.app/) | Window-based switching, thumbnails, keyboard workflows, and window search. | Add backwards cycling with Shift, paired key handling, and initial selection of the next window when the frontmost window leads the list. Search within the overlay remains a future feature. |
| [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704?mt=12) | Timed or indefinite keep-awake sessions. | Add a small local Keep Awake service using IOKit assertions, optional display wakefulness, and menu bar session controls. No triggers, helper installation, or closed-lid override. |
| [Bartender 7](https://www.macbartender.com/) | Searchable menu items, automation, profiles and advertised spacing controls for macOS 27. | Add settings search and clearer quick controls. A menu-item manager is a separate project: this upgrade does not imply that writing legacy preferences reproduces Bartender's implementation. |
| [Ice](https://github.com/jordanbaird/Ice/discussions/588) | Its Tahoe announcement documents changed menu bar behavior and third-party relaunch requirements. | Treat successful preference writes and visible system changes separately. Keep readback verification and rollback. |

These are product comparisons, not copied implementations. No new third-party dependency or background agent was added.

## Menu bar spacing: current evidence

The evidence changed during this investigation. [Menu Bar Spacing's author](https://sindresorhus.com/menu-bar-spacing) reports that the old hidden settings stopped working with the macOS 27 menu bar rewrite. However, [Pelmet 0.3.0-beta.5, published September 23](https://github.com/fif7y/pelmet/releases/tag/v0.3.0-beta.5), explicitly claims changes to the clock and Control Center using those preferences plus a restart of **MenuBarAgent**. [Beta 7](https://github.com/fif7y/pelmet/releases/tag/v0.3.0-beta.7) adds a one-point setting.

Its tagged [IconSpacingApplier](https://github.com/fif7y/pelmet/blob/v0.3.0-beta.7/Pelmet/App/IconSpacingApplier.swift) and [spacing model](https://github.com/fif7y/pelmet/blob/v0.3.0-beta.7/Packages/PelmetCore/Sources/PelmetCore/IconSpacing.swift) identify a reproducible mechanism:

- Set `NSStatusItemSpacing` and `NSStatusItemSelectionPadding` in the **current-user, current-host global** preference domain.
- Use the requested spacing with selection padding bounded between 6 and 16, preserving room to click small icons.
- Restart `com.apple.MenuBarAgent`, the new system icon host, rather than Control Center. Relaunch other apps separately if needed.

This is primary-source evidence of a new working claim, not independent proof that **all** icons respond. A setting value is not an exact visible edge-to-edge gap: individual glyph widths, hit regions, protected indicators, and other hosts can differ. The Apple menu at the far left and application menu titles are also distinct from right-hand status items. [Apple's native menu bar guide](https://support.apple.com/guide/mac-help/customize-the-menu-bar-mchl4af84660/27/mac/27) does not document a public global gap control.

macMender's implementation:

- macOS 26 and older: preserve preference writes with Control Center refresh; disclose the possible screen-sharing interruption.
- macOS 27: report **unverified** system-wide support and do not restart MenuBarAgent during Apply. The newly reported path was tested locally before this decision; it did not move Apple’s items. macMender’s own item width can still update immediately.
- Future major versions: leave system refresh unconfirmed instead of assuming compatibility.
- Read back both keys after applying; restore the original values if either write fails. Reset deletes both overrides and restores macOS's choice of macMender icon width.
- The preview remains illustrative, not a pixel-accurate promise.

### Local verification: September 23, 2026

With the owner's approval, we measured Accessibility item frames on **macOS 27.0, build 26A428**, applied wide and tight settings through the upgraded macMender UI, verified both preference values, and confirmed that MenuBarAgent acquired a new process ID after each restart. A second tight-setting sample after the layout settled produced the same frames.

| Adjacent Apple items | Before | Wide (24 / 16) | Tight (1 / 6) | Restored |
| --- | ---: | ---: | ---: | ---: |
| Wi-Fi → Sound | 16 pt | 16 pt | 16 pt | 16 pt |
| Sound → Battery | 16 pt | 16 pt | 16 pt | 16 pt |
| Battery → Control Center | 16 pt | 16 pt | 16 pt | 16 pt |
| Control Center → Clock | 13.5 pt | 13.5 pt | 13.5 pt | 13.5 pt |

These are gaps between Accessibility frames (`next.x − previous.maxX`), not measurements of individual glyph pixels. All five items' settled frames were unchanged. The original global preferences were **0 / 0**; those exact values and the original macMender selection were restored, and all five frames matched the baseline again. Raw non-personal measurements are in [menu-bar-spacing-measurements.json](menu-bar-spacing-measurements.json).

**Result:** the reported MenuBarAgent method did not produce system-wide spacing changes on this Mac. This directly rules out claiming success for *all icons* in this test. It does not prove that another technique, OS build, or future release cannot work. Protected recording indicators, input-source items, other displays, and the left-hand Apple/application menus were not independently tested. We did not log out, change security settings, inject code, or restart third-party apps.

## Dock previews rebuild

Dock previews were rebuilt as their own feature instead of a mode of the window switcher.

- **Every window.** Discovery now includes minimized windows, windows of hidden apps, full-screen windows, and windows on other Spaces. Accessibility only lists windows on visible Spaces, so other-Space windows are found by probing remote Accessibility tokens and are confirmed against the window server before they are shown.
- **Interaction.** Each preview has close, minimize/restore, and full-screen buttons on hover. Middle-click closes. The context menu adds Close All, Hide, and Quit. Closing or minimizing updates the preview in place.
- **Peek.** Resting the pointer on a card for half a second shows that window at full size: in place when it is on screen, centered when it is minimized, hidden, or on another Space. The peek ignores the pointer and sits just beneath the preview.
- **Keyboard.** While the pointer is over a preview, arrow keys move between cards, Return brings the selected window forward, Command-W closes it, and Escape dismisses. A key-down event tap exists only while a preview is open, and it passes every key through unless the pointer is over the preview, so typing with the pointer parked on the Dock is unaffected.
- **Minimized windows in the Dock** show a preview of that window. The Dock tile carries only the window's title, so the owning application is found by matching minimized windows by title.
- **One window comes forward.** Clicking a preview raises that window only, switching Space when needed, instead of bringing every window of the app to the front.
- **Hover detection.** An Accessibility observer on the Dock reports the hovered icon. Pointer movement is only examined within the Dock's screen-edge band, so movement elsewhere costs a rectangle test rather than a round trip to the Dock.
- **Pointer behavior.** Sliding along the Dock swaps previews almost immediately. A corridor from the icon to the preview keeps it open while the pointer travels to a distant card, even across neighboring icons.
- **Thumbnails** are captured from the window server off the main thread, in parallel, and refresh while the preview is open.
- **Placement** follows the Dock: above a bottom Dock, beside a left or right Dock, on whichever display the Dock is on. Cards keep each window's proportions, wrap into balanced rows, shrink before any window is hidden, and report an overflow count beyond that.
- **Settings.** Schema 7 replaces the layout, thumbnail-width, and linger settings with preview size, a stay-open delay, and toggles for titles, window buttons, live previews, and which windows to include. Earlier settings decode unchanged; hover delay and animation duration move to the new defaults only if they were never customized.

Private interfaces used: `CGSHWCaptureWindowList` (capture), `_SLPSSetFrontProcessWithOptions` and `SLPSPostEventRecordTo` (single-window focus), `CGSCopySpacesForWindows` and `CGSCopyManagedDisplaySpaces` (Spaces), `_AXUIElementCreateWithRemoteToken` and `_AXUIElementGetWindow` (window identity). All are resolved at run time; if one disappears the feature degrades to public API (ScreenCaptureKit capture, whole-app activation, current-Space windows) rather than failing to launch. The implementation is independent of the GPL-licensed utilities that use the same interfaces.

Verified on macOS 27.2 (26B131) with a bottom, auto-hiding, magnified Dock on one display: hover, hand-off between icons, travel to the preview, close button, middle-click close, minimize and restore, single-window raise (confirmed by window-server order), activation of a full-screen window on another Space, peek, arrow-key selection with Return and Escape, and a minimized-window tile preview restoring its window. Not yet exercised on real hardware: left/right Docks and multiple displays (covered by unit tests of the geometry only).

## Architecture and behavior

- `ScrollEventPoster` owns one timer and a bounded momentum accumulator instead of scheduling 4–18 independent closures for every wheel event. The timer exists only while scrolling. Cancellation waits for the posting queue, so completed pauses cannot leave queued scroll events behind.
- `ScrollTransformer` resolves per-axis smoothing and gain. Explicit app overrides win; otherwise axis and device switches both need to permit smoothing. Trackpad/continuous input retains native momentum.
- `SwitcherKeyboardRouter` is independent of event-tap installation and can be tested without global keyboard access. Shift reverses direction; extra Command/Control modifiers do not accidentally trigger Option-Tab.
- `KeepAwakeService` owns assertion acquisition, replacement, expiration, and release. The injectable system boundary lets tests verify failures without changing the test machine's sleep state. Sessions do not persist or auto-start.
- `ProfileStore` respects task cancellation, reports save errors, flushes on normal application termination, writes imports before adopting them in memory, and backs up the current in-memory settings including pending edits.
- App lookup in the scroll path has a bounded, one-second cache. Thumbnail results publish once per batch instead of once per image. Sleep cancels active helpers; wake refreshes their state.
- Settings search matches section titles, descriptions, and useful synonyms. Existing view components and native sidebar controls are reused.

## Remaining work worth a separate change

1. Physical mouse/trackpad matching through HID: current classification distinguishes continuous input from discrete wheels, not individual hardware. The UI now says so and hides the ineffective separate Magic Mouse rule.
2. Window search and configurable per-application window exclusions. The current catalog and overlay can support this, but keyboard text routing needs its own interaction design.
3. Dock preview discovery runs off the main thread; the keyboard window switcher still discovers windows on the main thread and only lists the current Space. Move it onto the same engine.
4. Menu item organization using an independently validated macOS 27 implementation. Avoid unsupported Control Center preference guesses or process injection.
5. Developer ID signing, notarization, and a physical-device test matrix before moving beyond the public preview.

## Validation

Automated tests cover scroll distance conservation, rapid bursts, reversal, cancellation, axis precedence, native bypass, preset preservation, old configuration decoding, numeric limits, unsupported schemas, debounced saves, backups, import failure, keyboard routing, settings search, power assertion lifecycle, menu bar rollback/version policy, and Dock preview layout, placement, pointer safe zone, and settings migration. Tests use temporary settings directories and mocked power/preference operations; they do not change global preferences or grant permissions.

The [GitHub Actions workflow](../.github/workflows/ci.yml) builds, tests, and compiles release mode with Xcode 26.3 on macOS 15. It runs for pull requests and pushes to `main`, with a manual trigger available. Local build, test, UI inspection and optimized-build results are recorded in the upgrade PR. Hardware-specific scrolling feel and Apple system icon spacing are not inferred from unit tests.
