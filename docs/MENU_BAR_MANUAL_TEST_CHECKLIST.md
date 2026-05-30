# Menu Bar Manual Test Checklist

Use this checklist before calling the menu-bar manager release-ready.

## Setup

- Quit other menu-bar managers such as Ice, Bartender, Hidden Bar, Dozer, Vanilla, and Barbee.
- Quit duplicate macMender builds before testing. In particular, make sure older copies such as `/Users/ryan/Documents/macMender-copy/dist/macMender.app` are not running, because duplicate divider controls make physical movement and section detection invalid.
- Launch several real status-item apps, including at least one Apple Control Center module and one third-party menu extra.
- Confirm macMender has Accessibility permission.
- Build macMender and record whether `dist/macMender.app/Contents/XPCServices/MacMenderMenuBarItemService.xpc` is present.
- XPC service presence/connectivity: if the helper is present, it must launch without Console errors and keep source-PID resolution working after relaunch before claiming full Thaw XPC parity. If it is missing, record that as a packaging gap and continue with in-process source-PID validation only.
- Open macMender Settings > Menu Bar and press Scan Now.

## Mendy and Liquid Glass

- Confirm Mendy renders the local PNG state assets for greeting, happy, thinking, scanning, idle, sleeping, success, and error.
- Confirm Mendy state changes crossfade and use restrained motion; with Reduce Motion enabled, motion should simplify without losing state clarity.
- Confirm onboarding, permissions, empty states, menu bar guidance, and success/error feedback use state-specific Mendy artwork rather than the old generic head plus badge-only treatment.
- Confirm settings cards, sidebar, menu bar popover, and preview overlays use readable Liquid Glass surfaces in light and dark appearance.

## Discovery

- Menu Bar Layout should show `Live order sync` when Screen Recording is granted.
- If Screen Recording is missing, the panel should explain that live ordering is limited and offer Grant Access / Open Settings without implying that macMender records or uploads the screen.
- Finder, Messages, browsers, and other normal foreground apps must not appear as hideable menu-bar icons.
- Clock, Control Center, and transient capture/privacy modules must appear read-only if detected.
- Third-party status items with real WindowServer menu-bar windows should be offered as hideable.
- Generic `Item-0` Control Center hosts should only be hideable after source-PID matching identifies a real non-Control Center source app.
- Source-resolved `CombinedModules` hosts from real apps should be managed. Stats is the primary smoke-test case: all detected Stats items should be assignable to Visible, Hidden, or Always Hidden and should stay in the selected section across macMender relaunch.
- Search should filter by display title, owner name, and bundle identifier.
- Run discovery side by side with Thaw using the same status-item apps. Compare item count, display titles, source apps, read-only flags, duplicate handling, active-Space filtering, and Control Center-hosted item attribution.
- If the XPC helper is present, relaunch macMender and confirm discovery still source-resolves third-party Control Center hosts with no XPC listener, entitlement, launch, or connection failures in Console.

## Section Assignment

- Move an item to Visible. It should stay visible after relaunching macMender.
- Move an item to Hidden. It should tuck behind the hidden divider and reveal only via configured triggers.
- During repeated hide/reveal/rehide attempts, pointer coordinates should remain stable. Record `CGEvent(source: nil)?.location` before and after five repeated attempts; macMender must not snap the pointer to a chip, divider, Dock, or screen edge.
- Stored Hidden intent should drive runtime concealment even when the item starts physically visible. Example: set Codex to Hidden, relaunch macMender, and confirm the hidden divider expands, Codex is physically concealed, and Codex appears in the Hidden lane after live refresh.
- Hiding one item should not hide unrelated items that remain in Visible.
- Move an item to Always Hidden. It should stay behind the Always Hidden divider until explicitly revealed or moved out.
- Move Codex or another third-party item Hidden → Always Hidden → Hidden and verify the lane row, saved section, and WindowServer divider placement all agree.
- Move Stats from Visible to Hidden, Hidden to Always Hidden, and Always Hidden back to Visible. Each transition should update the real menu bar, not just the settings UI.
- Drag-and-drop between Visible, Hidden, and Always Hidden lanes should match the layout behavior.
- Dragging over a lane should clearly highlight that lane as the active drop target, and the highlight should disappear after drop or cancel.
- Target lane drop-slot reservation should be visible while crossing lanes: the destination lane should reserve a clear incoming slot, not merely tint the background.
- Lane chips should be compact and icon-first. Supported items should show their real menu-bar icon snapshot; only items without a readable icon should fall back to a small initial.
- Moving chips within a lane or between lanes should animate smoothly. When inserting between two icons, an in-lane insertion marker should appear at the intended slot, neighboring chips should slide aside during the drag, and the dropped chip should glide into place without jitter or layout thrash.
- Target lane highlight behavior should be obvious while dragging between Visible, Hidden, and Always Hidden, then fade away after drop or cancel.
- Matched item movement should preserve visual continuity from the lifted chip to its final lane/slot, with no duplicate ghost, duplicate live chip, stale source chip, snap-back, or abrupt relayout.
- After every drop, each managed item should appear as one live chip in exactly one lane after live refresh or Scan Now. A repeated tag/title/source in multiple lanes is a blocker.
- With Reduce Motion enabled, expected Reduce Motion behavior is simplified movement with quick fades/position changes while still making the destination clear.
- Multi-icon apps such as Stats should use a wider icon preview that remains recognizable without making the whole lane feel oversized.
- Run the deterministic order sequence: hide Stats, hide Wi-Fi, show Wi-Fi, drag Stats before Codex. Visible order should remain Wi-Fi, Stats, Codex in-session and after relaunch.
- Command-drag a supported icon directly in the real menu bar while Menu Bar Layout is open. The lanes should mirror the new physical order within about two seconds; Scan Now should preserve that same order and must not silently move visible items into Hidden.
- Mendy should appear as a Visible chip that mirrors the real macMender status-item position. Drag Mendy left/right inside Visible and confirm the physical menu-bar icon moves without changing sections.
- Repeat five drag/cancel and drag/drop attempts across lane boundaries and within Visible. Pointer coordinate stability should pass throughout; the pointer must remain continuous while the mouse button is down and after the drop.
- Stored hidden selections for currently closed apps should remain listed and removable.
- Repeat the same hide, Always Hidden, and reorder cases under Thaw. macMender should match Thaw's divider boundaries, physical WindowServer order, stored order after relaunch, and handling of source-resolved Stats/multi-icon apps.
- Side-by-side Thaw animation comparison: drag within a lane and between lanes in macMender and Thaw, then compare in-lane insertion markers, target lane highlight timing, matched item movement, and Reduce Motion behavior.
- For every drag, hide, reveal, and rehide parity case, record Thaw-vs-macMender parity status fields for scenario name, item tag/title/source, starting section, requested section, final macMender section, final Thaw section, macMender physical divider boundary, Thaw physical divider boundary, macMender reveal state, Thaw reveal state, live-order status text (`Live order sync` or `Live order limited`), pointer coordinate stability status, duplicate/ghost live-chip status, and pass/fail parity result.

## Reveal Triggers

- Hover over Mendy in the menu bar; hidden items should reveal smoothly.
- Hover over open menu-bar space near Mendy; hidden items should reveal only inside the Mendy reveal zone, not from arbitrary menu-bar positions.
- Click empty menu-bar space near Mendy; hidden items should toggle when that setting is enabled.
- Scroll or swipe near Mendy; positive/negative scroll should reveal/hide when that setting is enabled.
- Move the pointer away from Mendy's reveal zone and the secondary bar; hidden items should tuck away after the configured delay.
- Disable each trigger in settings and verify that it no longer fires.
- Repeat hover, click, scroll, and auto-rehide five times while watching pointer coordinate stability. Revealing and rehiding must not warp the pointer or synthesize visible pointer motion.
- Repeat hover, empty-space click, scroll/swipe, trigger disablement, and reveal-zone boundary checks side by side with Thaw.

## Auto-Rehide

- With auto-rehide on, revealed items should hide after the configured delay once the pointer leaves the menu bar and secondary bar.
- With auto-rehide off, revealed items should remain visible until manually hidden.
- Rehide should not warp the pointer or interrupt normal clicks.
- Hide/show and drag/drop should never move the visible pointer across the menu bar.

## App Menu Overlap

- Use a foreground app with many menu titles.
- Reveal hidden items until they would collide with app menus.
- With overlap hiding enabled, app menus should temporarily clear and return after rehide.
- With overlap hiding disabled, macMender should not activate/hide app menus.

## Secondary Bar

- Enable "Show hidden icons in a separate bar."
- Trigger reveal by hover, click, and scroll/swipe.
- The separate bar should appear just below the menu bar, use translucent styling, and avoid the notch area as much as possible.
- Press the reveal-in-menu-bar button; hidden items should show in the real menu bar.
- Press a hidden item chip; that item should move back to Visible in both the settings UI and the real menu bar.
- Use Codex or another third-party item for at least one secondary-bar cycle. The bar must not keep showing the item after it returns to Visible.
- Move the pointer away and confirm the secondary bar dismisses after the auto-rehide delay.
- Disable the secondary bar and verify hidden items reveal in the real menu bar again with no stuck overlay.
- Repeat the secondary-bar flow side by side with Thaw: ordinary Hidden items should appear in the bar, Always Hidden items should stay excluded, reveal-in-menu-bar should show the real status item, and returning an item to Visible should remove it from the bar.

## Environment Parity

- Screen Recording off: deny or remove permission, relaunch macMender, and verify the UI reports limited live order while saved layout operations remain understandable. Repeat under Thaw if possible and record differences.
- Screen Recording on: grant permission, relaunch, and verify live WindowServer order sync matches Thaw for discovery, reorder, hidden-item visibility, and source-resolved Stats/multi-icon apps.
- Auto-hidden menu bar: enable System Settings > Control Center > Automatically hide and show the menu bar, then repeat discovery, reveal triggers, auto-rehide, and secondary-bar checks while the system menu bar is hidden and shown.
- Full-screen: put a normal app in full-screen and repeat reveal, rehide, secondary-bar, and Scan Now checks. macMender should not leave stuck overlays when entering or leaving full-screen.
- Multiple displays: attach a second display or Sidecar/AirPlay display and repeat discovery, reveal, rehide, reorder, and secondary-bar checks on each active display.

## Spacing

- Move the spacing slider to a positive value and apply. Relaunch at least one status-item app if needed.
- Move the spacing slider to a negative value and apply.
- Restore spacing to 0 and verify the status text reports the default was restored.

## Regression Checks

- macMender's own menu-bar icon should still open the popover consistently.
- With "Hide Dock icon while running" enabled, relaunching macMender should not flash a Dock icon, and opening Settings from the menu bar should keep the window in front until the user switches away.
- The settings window should stay responsive while moving items.
- CPU usage should remain idle-level when the pointer is not in the menu bar.
- No menu-bar items should be permanently lost; use Visible for all managed items before disabling the feature.
