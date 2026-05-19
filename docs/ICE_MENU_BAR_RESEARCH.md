# Ice Menu Bar Research

This note captures the implementation details from the Ice for macOS source that matter for macMender's menu bar rewrite.

## How Ice Feels Smoother

Ice does not drag user menu bar items every time the user reveals or hides them. It creates its own status-item delimiters:

- visible control item: the Ice icon
- hidden control item: divider between visible and hidden items
- always-hidden control item: divider for the always-hidden section

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

macMender now has a small private bridge for the menu bar window list and frame lookup. This lets us attach real window IDs to detected items where possible and avoid relying only on Accessibility frames. It also uses Ice-style stable control item autosave names (`SItem`, `HItem`, `AHItem`) so macOS preserves predictable ordering for the visible, hidden, and always-hidden section controls.

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
- hides the cursor during movement
- posts targeted events to the owning process and session event tap
- verifies frame changes
- retries failed moves
- restores cursor position afterward

macMender now hides/restores the cursor for private-window-backed movement, routes events through Ice-style taps, verifies frame changes, and only offers items backed by real WindowServer menu-bar windows. The scanner no longer creates hideable rows from generic app windows or AX-only guesses, which prevents false positives like Finder, Messages, or browser app windows. Apple modules follow Ice-style controllability rules where possible, while fixed items such as Clock remain read-only.

## Feature Mapping

- Hide menu bar items: use section delimiters and one-time movement into the hidden region.
- Always-hidden section: use the existing second delimiter and expose it in the section UI.
- Hover reveal: implemented.
- Empty menu-bar click reveal: implemented.
- Scroll/swipe reveal: implemented.
- Auto rehide: implemented.
- Hide application menus on overlap: implemented as a conservative compatibility path that temporarily activates macMender when revealed items would collide with the active app menu.
- Drag-and-drop arrangement: implemented at the section level, with segmented controls as the precise fallback.
- Separate hidden bar: still planned; this requires an `NSPanel`/SwiftUI overlay similar to Ice Bar plus item click forwarding for notched MacBooks.
- Search menu bar items: implemented in the Menu Bar preferences pane.
- Menu bar spacing: already partially implemented by writing `NSStatusItemSpacing` and `NSStatusItemSelectionPadding`; Ice additionally relaunches affected menu-bar apps so changes take effect.
