# Ice Menu Bar Research

This note captures the implementation details from the Ice for macOS source that matter for macMender's menu bar rewrite.

## How Ice Feels Smoother

Ice does not drag user menu bar items every time the user reveals or hides them. It creates its own status-item delimiters:

- visible control item: the Ice icon
- hidden control item: divider between visible and hidden items
- Always Hidden control item: divider for the Always Hidden section

Normal show/hide changes the control item state and width. The hidden divider becomes very wide when hidden and returns to normal width when shown. User items only need to move when the user arranges sections, not every reveal.

Relevant Ice files:

- `Ice/MenuBar/ControlItem/ControlItem.swift`
- `Ice/MenuBar/MenuBarSection.swift`
- `Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift`
- `Ice/Events/EventManager.swift`
- `Ice/Bridging/Bridging.swift`

## Private APIs Ice Uses

Ice uses private CoreGraphics Services APIs to enumerate and target menu bar item windows:

- `CGSGetProcessMenuBarWindowList`
- `CGSGetScreenRectForWindow`
- `CGSGetWindowList`
- `CGSGetOnScreenWindowList`
- `CGSCopySpacesForWindows`

It also writes status item defaults:

- `NSStatusItem Preferred Position <autosaveName>`
- `NSStatusItem Visible <autosaveName>`

macMender now has a small private bridge for the menu bar window list and frame lookup. This lets us attach real window IDs to detected items where possible and avoid relying only on Accessibility frames. It also uses Ice/Thaw-style stable control item autosave names (`macMender.ControlItem.Visible`, `macMender.ControlItem.Hidden`, `macMender.ControlItem.AlwaysHidden`) so macOS preserves predictable ordering for the Visible, Hidden, and Always Hidden section controls.

## Reveal Triggers

Ice uses combined local and global monitors for:

- mouse moved
- mouse down
- mouse dragged
- scroll wheel

It reveals hidden items when the pointer is in empty menu bar space, can toggle on empty-space click, and supports scroll/swipe reveal. macMender now mirrors the important runtime behavior:

- hover Mendy
- hover empty menu-bar space
- click empty menu-bar space
- scroll/swipe in the menu bar
- timed auto rehide after leaving the menu bar

## Movement

Ice still uses synthetic movement for arrangement, but it does it carefully:

- waits for no modifiers and no recent mouse movement
- posts targeted events to the owning process and session event tap
- verifies frame changes
- retries failed moves

macMender routes explicit arrangement through Ice-style taps, verifies frame changes, and only offers items backed by real WindowServer menu-bar windows. Unlike Ice/Thaw, macMender does not call cursor-warp or cursor-hide APIs during normal menu-bar management; movement uses targeted events only, so the pointer should not visibly jump. The scanner no longer creates hideable rows from generic app windows or AX-only guesses, which prevents false positives like Finder, Messages, or browser app windows. Apple modules follow Ice-style controllability rules where possible, while fixed items such as Clock and unresolved generic Control Center hosts remain read-only.

## Thaw Source-PID Layer

Thaw adds newer macOS source-PID handling for Control Center-hosted status-item windows. macMender now mirrors the core idea in-process:

- enumerate WindowServer menu-bar item windows,
- inspect running apps' `AXExtrasMenuBar` children,
- match child frames to WindowServer window centers,
- assign a source PID/bundle to generic Control Center-hosted items,
- ignore accidental self-matches for non-control items so macMender does not claim ownership of Wi-Fi or other moved icons.

This is intentionally isolated in `MenuBarSourcePIDResolver` so it can later become an XPC helper if the AX pass becomes too expensive or needs stronger lifecycle isolation.

## Feature Mapping

- Hide menu bar items: use section delimiters and one-time movement into the hidden region. Before the first explicit hide action, macMender normalizes currently visible items to the visible side of the hidden divider so one hidden icon does not conceal unrelated visible icons.
- Always Hidden section: use the existing second delimiter and expose it in the section UI.
- Hover reveal: implemented.
- Empty menu-bar click reveal: implemented.
- Scroll/swipe reveal: implemented.
- Auto rehide: implemented.
- Hide application menus on overlap: implemented as a conservative compatibility path that temporarily activates macMender when revealed items would collide with the active app menu.
- Drag-and-drop arrangement: implemented at the section level, with segmented controls as the precise fallback.
- Separate hidden bar: first pass implemented as a SwiftUI/AppKit `NSPanel` that lists hidden items, can move an item back to Visible, and includes a reveal-in-menu-bar action. Direct status-item menu forwarding is intentionally deferred until it can be tested across third-party menu extras.
- Search menu bar items: implemented in the Menu Bar preferences pane.
- Menu bar spacing: already partially implemented by writing `NSStatusItemSpacing` and `NSStatusItemSelectionPadding`; Ice additionally relaunches affected menu-bar apps so changes take effect.
