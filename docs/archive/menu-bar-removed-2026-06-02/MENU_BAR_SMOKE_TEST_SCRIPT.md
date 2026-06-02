# macMender Menu Bar Smoke Test Script

This script is the release gate for menu bar management. Run it with Ice closed unless the step explicitly asks for Ice comparison.

Current runtime-transplant status: physical menu-bar hide/reveal/reorder is intentionally disabled in macMender until the full Thaw runtime shape is transplanted. For the current pass, the expected result for hide, reveal, Always Hidden, secondary bar movement, and drag/reorder steps is a clear disabled state with no cursor movement, no context menu activation, and no fake success. Do not claim Thaw parity from this pass.

## 0. Reset

1. Quit other menu-bar managers: Ice, Thaw, Bartender, Hidden Bar, Dozer, Vanilla, Barbee.
2. Confirm only the current macMender build is running. Duplicate builds install duplicate divider controls and invalidate movement results:

   ```sh
   pkill -f '/Users/ryan/Documents/macMender-copy/dist/macMender.app' || true
   pgrep -lf 'macMender|MacMenderMenuBarItemService'
   ```

   Only `dist/macMender.app` and its bundled `MacMenderMenuBarItemService.xpc` should remain.
3. Build and launch macMender:

   ```sh
   script/build_and_run.sh run
   ```

4. Confirm the built app bundle's Thaw-style XPC service state:

   ```sh
   test -d dist/macMender.app/Contents/XPCServices/MacMenderMenuBarItemService.xpc && echo "xpc present" || echo "xpc missing"
   ```

   If `xpc present`, continue by checking helper launch/connect behavior and source-PID resolution after relaunch. If `xpc missing`, record it as a packaging gap and continue with in-process source-PID validation. Do not claim full Thaw XPC parity until helper presence, launch/connect behavior, and source-PID parity are verified.
5. Open Settings > Menu Bar.
6. Enable menu bar hiding.
7. Press Scan Now.

## 1. Discovery Parity

1. Record macMender's detected list from Settings > Menu Bar.
2. Confirm Settings > Menu Bar shows `Live order sync`.
   - If it shows `Live order limited`, use the in-panel Screen Recording banner to grant access.
   - The permission is used only to read menu-bar item windows and positions; macMender must not save, stream, or send screen content.
3. Quit macMender.
4. Launch Ice or Thaw with the same status-item apps running.
5. Record its item list/layout view.
6. Compare:
   - Every real status item Ice exposes should appear in macMender unless macOS reports it as zero-width/transient.
   - Stats, Hammerspoon, iStat Menus, and other multi-icon apps should appear as source-resolved app items, not as generic read-only Control Center rows.
   - Clock and Control Center should be read-only.
   - Normal app windows such as Finder, Messages, Mail, and browsers must not appear.
   - Duplicate rows with the same title/source should not appear.
7. If the XPC helper is present, confirm source-PID resolution still works after quitting and relaunching macMender. Console should not show `MacMenderMenuBarItemService` launch, listener, entitlement, or connection failures.

Useful WindowServer dump:

```sh
swift -e 'import AppKit; typealias CGSConnectionID=Int32; @_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> CGSConnectionID; @_silgen_name("CGSGetWindowCount") func CGSGetWindowCount(_ cid: CGSConnectionID,_ targetCID: CGSConnectionID,_ outCount: inout Int32) -> CGError; @_silgen_name("CGSGetProcessMenuBarWindowList") func CGSGetProcessMenuBarWindowList(_ cid: CGSConnectionID,_ targetCID: CGSConnectionID,_ count: Int32,_ list: UnsafeMutablePointer<CGWindowID>,_ outCount: inout Int32) -> CGError; var count:Int32=0; _=CGSGetWindowCount(CGSMainConnectionID(),0,&count); var list=[CGWindowID](repeating:0,count:Int(count)); var real:Int32=0; _=CGSGetProcessMenuBarWindowList(CGSMainConnectionID(),0,count,&list,&real); var ptrs=Array(list.prefix(Int(real))).map{ UnsafeRawPointer(bitPattern:Int($0)) }; let arr=CFArrayCreate(kCFAllocatorDefault,&ptrs,ptrs.count,nil)!; let desc=CGWindowListCreateDescriptionFromArray(arr) as! [[String:Any]]; for d in desc { let name=d[kCGWindowName as String] as? String ?? ""; let owner=d[kCGWindowOwnerName as String] as? String ?? ""; let b=d[kCGWindowBounds as String] as? NSDictionary; print("owner=\(owner) name=\(name) ons=\(d[kCGWindowIsOnscreen as String] ?? "") x=\(b?["X"] ?? "") w=\(b?["Width"] ?? "")") }'
```

## 2. Hide and Show

1. Move Wi-Fi to Hidden.
2. Run the WindowServer dump above and confirm:
   - `WiFi` is offscreen or not onscreen behind the expanded `macMender.ControlItem.Hidden`.
   - unrelated visible items such as Stats, Battery, WeatherMenu, Sound, or Codex remain onscreen.
   - the cursor did not visibly jump during the operation.
   - pointer coordinates stay stable before and after the hide attempt. Record `CGEvent(source: nil)?.location`, repeat the hide/reveal/rehide sequence five times without moving the pointer intentionally, and confirm only normal hand movement is reflected.
3. Hover over Mendy in the menu bar.
4. Confirm Wi-Fi appears again while the hidden section is revealed.
5. Move the pointer away from the menu bar.
6. Confirm Wi-Fi rehides after the configured delay.
7. Move Wi-Fi back to Visible.
8. Confirm it returns and remains visible after relaunching macMender.
9. Repeat the same hide/show cycle with at least one third-party item that macMender marks hideable, such as Codex or WeatherMenu.
   - Codex-specific regression: set Codex to Hidden, relaunch macMender, and confirm Codex is physically behind `macMender.ControlItem.Hidden` and appears in the Hidden lane. This catches the startup case where stored Hidden intent must expand the divider even before the live scan reports a physically hidden item.
10. Repeat the cycle with Stats when it is running:
   - Stats may appear as a source-resolved `CombinedModules` host.
   - Moving Stats to Hidden must physically conceal the `CombinedModules` window behind `macMender.ControlItem.Hidden`.
   - Hover/click/scroll reveal should show Stats only while the Hidden section is revealed.
   - Moving Stats back to Visible must return it to the visible menu bar without hiding Wi-Fi, Battery, Sound, or other unrelated visible items.
   - Relaunch macMender and confirm Stats remains in its stored section and visible order.
11. Deterministic same-session ordering sequence:
   - Start with Stats, Wi-Fi, and Codex in Visible.
   - Move Stats to Hidden.
   - Move Wi-Fi to Hidden.
   - Move Wi-Fi back to Visible.
   - Drag Stats back to Visible before Codex.
   - Confirm Visible order is Wi-Fi, Stats, Codex and remains the same after relaunch.
   - Confirm hiding either Stats or Wi-Fi did not reshuffle unrelated visible items.
12. Direct menu-bar ordering sync:
   - Put Stats, Codex, WeatherMenu, and Mendy in Visible.
   - Command-drag one supported status item directly in the real menu bar.
   - Keep Settings > Menu Bar open.
   - Confirm the Visible lane mirrors the real menu-bar order for supported items within about two seconds.
   - Press Scan Now and confirm the same order remains.
   - Confirm an item that is physically visible in the real menu bar never remains labeled Hidden or Always Hidden in macMender after the live sync.
   - Drag Mendy inside the Visible lane between two other items, then confirm the real macMender menu-bar icon moves to the same relative spot and stays there after relaunch.

## 3. Always Hidden

1. Move one item to Always Hidden.
2. Relaunch macMender and confirm the item remains physically behind `macMender.ControlItem.AlwaysHidden`, not merely in the ordinary Hidden band.
3. Confirm normal Hidden reveal does not show it unless the Always Hidden divider/action is used.
4. Move it back to Visible.

## 4. Drag and Drop

1. Drag an item from Visible to Hidden.
2. Confirm the chip does not leave behind stale optimistic row state. During drag it may show target feedback; after drop, the lane should update from live WindowServer refresh or Scan Now, and the real menu bar should hide it.
   - The live chip should exist once in exactly one lane after the drop. There must be no ghost chip, duplicate chip, stale source chip, or second live row for the same tag/title/source after live refresh or Scan Now.
3. While dragging, confirm the target lane highlight appears with a visible tint/glow and the label matches the lane that will receive the item.
   - Target lane drop-slot reservation: when dragging over a different lane, the destination lane should visibly make room for the incoming chip instead of only changing color.
4. Confirm the chip uses the real status-item icon where available and falls back only to a small initial when no icon can be captured.
5. Drag the same item from Hidden to Always Hidden.
6. Confirm the chip moves into the Always Hidden lane and normal Hidden reveal does not show it.
7. Drag it back from Always Hidden to Visible.
8. For Codex or another third-party item, also verify Hidden → Always Hidden → Hidden. The config section, WindowServer divider placement, and lane row must all agree after live refresh or Scan Now.
9. Drag it onto another chip in Visible.
10. Confirm the real menu bar places it before that target chip.
11. While dragging within Visible, pause between two icons. The in-lane insertion marker should appear exactly between the intended neighbors, and neighboring chips should visibly slide aside before drop.
12. Drop the chip and confirm matched item movement: the dragged chip should glide from its drag position into the final slot without snapping, duplicate ghosting, duplicate live chips, or jitter.
13. With Stats running, confirm its chip uses a wider, readable multi-icon preview and does not look squashed beside single-icon chips.
14. Drag Mendy left and right within Visible. It should move horizontally only, remain Visible, and keep opening the macMender popover. Its chip should use the live captured status icon, not a separate avatar rendering.
15. During each drag, watch the pointer. It must not jump while the mouse button is down. Repeat at least five drag/cancel and drag/drop attempts across lane boundaries and within Visible; pointer coordinates must remain continuous and must not snap to chip centers, dividers, the Dock, or screen edges.
16. Animation sanity check: compact icon chips should slide into place with one consistent easing curve, the target lane highlight should fade in/out, and Reduce Motion behavior should simplify movement to quick fades/position changes rather than bounce or spring.
17. Relaunch macMender and confirm no automatic reshuffle occurs unless a stored hidden item is explicitly revealed or moved.

## 5. Reveal Triggers

1. Enable hover, empty-area click, scroll/swipe, and auto-rehide.
2. Put one item in Hidden.
3. Hover over Mendy: item reveals.
4. Move away from Mendy's reveal zone and the secondary bar: item rehides after the configured delay.
5. Click empty menu-bar space near Mendy: item toggles.
6. Click empty menu-bar space far from Mendy: item should not reveal from that arbitrary location.
7. Scroll/swipe near Mendy: item reveals/hides depending on scroll direction.
8. Scroll/swipe elsewhere in the menu bar: item should not reveal from that arbitrary location.
9. Disable each trigger and confirm it stops firing.
10. For hover, click, and scroll reveal attempts, repeat the trigger five times and confirm pointer coordinates stay stable. Revealing or rehiding items must not warp the pointer or synthesize visible pointer motion.

## 6. Secondary Bar

1. Enable "Show hidden icons in a separate bar."
2. Put one third-party item, preferably Codex, in Hidden.
3. Hover over Mendy.
4. Confirm the separate translucent bar appears below the menu bar.
5. Confirm ordinary Hidden items appear in the secondary bar but Always Hidden items do not.
6. Click the reveal-in-menu-bar button and confirm the item appears in the real menu bar.
7. Click the Codex/item chip and confirm it moves back to Visible in both the settings UI and real menu bar.
8. Move the pointer away and confirm the secondary bar disappears after the auto-rehide delay.
9. Disable the secondary bar and confirm no overlay remains visible.
10. Relaunch macMender and confirm Codex does not appear in the secondary bar unless it is still stored in Hidden.

## 7. Thaw Side-by-Side Parity Matrix

Run each case with the same status-item apps under macMender, then quit macMender and repeat under Thaw 1.2.0. Record any visual or WindowServer-layout difference.

For every drag, hide, reveal, and rehide scenario below, record these Thaw-vs-macMender parity status fields: scenario name, item tag/title/source, starting section, requested section, final macMender section, final Thaw section, macMender physical divider boundary, Thaw physical divider boundary, macMender reveal state, Thaw reveal state, live-order status text (`Live order sync` or `Live order limited`), pointer coordinate stability status, duplicate/ghost live-chip status, and pass/fail parity result.

1. XPC service presence/connectivity:
   - macMender: `dist/macMender.app/Contents/XPCServices/MacMenderMenuBarItemService.xpc` should exist once the helper is implemented; until then, record this as the known XPC parity gap.
   - Thaw: confirm `Thaw.app/Contents/XPCServices/MenuBarItemService.xpc` exists.
   - With the helper present, source-PID resolution must continue to identify Control Center-hosted third-party items after app relaunch.
2. Discovery:
   - Compare item count, names, source apps, read-only status, duplicate handling, and active-Space filtering.
3. Hide and Always Hidden:
   - Move the same third-party item through Visible, Hidden, Always Hidden, and back to Visible. Physical menu-bar placement should match Thaw, including divider boundaries.
   - For each move, record the parity status fields listed above and confirm the pointer coordinate stability status passes after repeated hide/reveal attempts.
4. Reorder:
   - Command-drag in the real menu bar and drag chips in the layout UI. Stored order and live physical order should converge the same way as Thaw after scan and relaunch.
   - Side-by-side Thaw animation comparison: drag within a lane and between lanes in both apps, then compare in-lane insertion markers, target lane highlight timing, matched item movement, and Reduce Motion behavior.
   - After every drop, record duplicate/ghost live-chip status. A scenario fails parity if macMender shows a ghost, duplicate live chip, stale source chip, or a second row for the same item when Thaw does not.
5. Secondary bar:
   - Enable the separate hidden-item bar. Hidden items should appear there, Always Hidden items should not, and returning an item to Visible should update the real menu bar.
6. Reveal triggers:
   - Compare hover near Mendy/Thaw's control item, empty-space click, scroll/swipe, trigger disablement, and auto-rehide delay.
   - Record reveal state and pointer coordinate stability status for each hover, click, scroll, auto-rehide, and disabled-trigger case.
7. Stats and multi-icon apps:
   - With Stats running, verify source-resolved `CombinedModules`/multi-icon records can be discovered, hidden, always hidden, revealed, reordered, and restored without affecting unrelated visible items.
8. Screen Recording off/on:
   - With Screen Recording denied, macMender should clearly report limited live order while preserving saved layout behavior. With Screen Recording granted, live order sync should match Thaw's physical WindowServer order.
9. Auto-hidden menu bar:
   - Enable System Settings > Control Center > Automatically hide and show the menu bar. Repeat discovery, reveal, rehide, and secondary-bar checks while the system menu bar is hidden and while it is shown.
10. Full-screen:
    - Put a normal app in full-screen, then repeat reveal, rehide, secondary-bar, and Scan Now checks from that Space. No overlay should remain stuck when leaving full-screen.
11. Multiple displays:
    - Attach a second display or Sidecar/AirPlay display. Repeat discovery, reveal, rehide, reorder, and secondary-bar checks on the active display, then move focus to the other display and repeat.

## 8. Spacing

1. Set spacing to `-16`, click Apply, and wait for the relaunch wave to finish.
2. Confirm status text reports that spacing was applied and apps were relaunched.
3. Visually confirm tighter status-item spacing.
4. Set spacing to `16`, click Apply, and confirm wider spacing.
5. Set spacing to `0`, click Apply, and confirm default spacing is restored.

## 9. Resource Check

1. Leave macMender idle for one minute.
2. Check CPU:

   ```sh
   ps -o pid,%cpu,%mem,rss,command -p "$(pgrep -x macMender | tail -1)"
   ```

3. Idle CPU should settle near zero except during active movement, reveal, spacing relaunch, or short mood-change animations.
4. Leave Settings > Menu Bar open for one minute with Live order sync enabled. CPU should remain low; short spikes during the roughly 1.5-second live scan are acceptable, sustained usage is not.

## 10. Activation and Dock Icon

1. Open Settings > Privacy and Permissions.
2. Enable "Hide Dock icon while running."
3. Move the pointer to a visible reference point that is not the Dock or menu bar.
4. Record the pointer position:

   ```sh
   swift -e 'import CoreGraphics; print("before", CGEvent(source: nil)?.location ?? .zero)'
   ```

5. Use the macMender menu bar item dropdown and choose Open Settings.
6. Record the pointer position again:

   ```sh
   swift -e 'import CoreGraphics; print("after", CGEvent(source: nil)?.location ?? .zero)'
   ```

7. Confirm the preferences window comes to the front and stays there until you close it or switch to another app.
8. Confirm the pointer did not jump, sweep to the Dock, or generate any visible clicks.
9. Close the window, switch to another app, and repeat steps 3-8 five times from the menu bar item.
10. Repeat with "Hide Dock icon while running" disabled and activate macMender from the Dock.
11. Repeat from the Command-, settings shortcut if the app is already focused.
12. Quit and relaunch macMender with "Hide Dock icon while running" still enabled.
13. Confirm the Dock icon does not flash into view before hiding.
14. Open Settings from the menu bar item and confirm the window comes forward without popping behind the previously frontmost app.
15. Any Dock click, cursor relocation, phantom click, Dock-icon flash, or window pop-behind during activation is a blocker.

Development cursor-position check:

```sh
swift -e 'import CoreGraphics; print(CGEvent(source: nil)?.location ?? .zero)'
```

Activation paths that must remain passive:

- Dock icon click.
- macMender menu bar item > Open Settings.
- Command-, settings command.
- Bundle launch or relaunch.
- Any future URL or CLI trigger that opens Settings.
