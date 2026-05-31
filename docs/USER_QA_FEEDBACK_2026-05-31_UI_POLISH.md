# User QA Feedback - 2026-05-31 UI Polish

Branch context:
`codex/performance-preview-cleanup`

Current overall status:
Most major functionality is working much better now. Dock previews appear accurate, Option+Tab discovery is improved, menu bar physical movement is correctly disabled, and performance is much better after the preview cleanup pass.

This next pass should focus on UI, UX, polish, delight, and clarity. Do not add new core system functionality.

## Main Product Direction

macMender should feel like a premium, playful, first-party macOS utility.

The app should not feel like:

* a dark debug dashboard
* a technical settings dump
* a warning-heavy utility
* a fake menu bar manager
* a mascot pasted onto ordinary cards

The app should feel like:

* a polished local Mac utility
* a friendly system companion
* a clear status dashboard
* a focused set of useful controls
* a calm, delightful experience with Mendy as a guide

## Menu Bar Popover Feedback

The macMender menu bar dropdown should be much simpler.

Current issue:
The popover still feels too cluttered and too instructional. It should not be a tutorial, marketing panel, or mini settings window.

Desired direction:
Make it a slim live status dashboard.

It should accurately show:

* macMender is running
* Accessibility permission state
* Screen Recording permission state
* Input Monitoring state, if available or relevant
* Dock Previews status
* Window Switcher status
* Menu Bar Setup status as Safe Guide or disabled/future runtime

It should avoid:

* long paragraphs
* generic text
* repeated menu bar setup instructions
* fake hidden icon syncing claims
* large action rows
* cluttered buttons
* overexplaining Command-drag

Preferred popover structure:

* small Mendy avatar
* app name: macMender
* status: Running, Limited, Needs Attention, or Paused
* one short status sentence
* compact live status rows or chips
* Open Settings
* Check Permissions only when useful
* Learn Menu Bar Setup as a small link only if needed
* Quit macMender as a small lower-priority footer action

The popover should feel like:
“Here is macMender’s live status at a glance.”

Not:
“Here is a full settings/tutorial page.”

## Overview Page Feedback

The Overview page is functional but still visually flat.

Pain points:

* too many equal-weight cards
* repeated dark glass panels
* weak hierarchy
* Mendy is present but not strongly meaningful
* the page does not yet feel like a premium dashboard

Desired direction:
Make Overview answer:
“Is macMender healthy, and what is it watching?”

Improve:

* Current Profile as a stronger hero card
* system health summary
* live modules for Runtime and System Access
* shorter, more confident copy
* more visual hierarchy
* less same-weight card repetition
* Mendy as a contextual status guide

## Menu Bar Page Feedback

The Menu Bar page is safer and more honest now, but still feels too cluttered.

Current desired state:
The Menu Bar page should stay focused on safe planning and manual setup.

Keep:

* physical movement disabled
* no direct hide/reorder/reveal controls
* no fake Show/Tuck hidden area controls
* detected app icons where possible
* read-only discovery
* session-only Mark to Review planning

Improve:

* make the page simpler
* reduce explanation clutter
* move long safety explanations into a disclosure such as “Why manual setup?”
* make detected icons more compact and scannable
* make Mark to Review visually lighter
* avoid repeating “Visible now” too heavily
* make it feel like a helpful planning page, not a disabled feature page

The page should feel like:
“Pick icons to review, then use Command-drag when macOS allows.”

Not:
“This feature cannot work.”

## Privacy and Permissions Feedback

The Privacy page is understandable but too utilitarian.

Improve:

* make it feel like a guided checklist
* use space better
* make granted permissions feel complete and calm
* make missing permissions clear without feeling alarming
* improve the drag-to-add guide
* use Mendy as a guide, not decoration
* keep real permission checks as the only source of truth

The page should answer:
“What access does macMender need, why, and what is already done?”

## Advanced Page Feedback

The Advanced page feels sparse and unfinished.

Improve:

* make it feel intentional
* split into Local Diagnostics, Recovery Tools, and Technical Status
* move dense implementation notes into disclosures
* keep recovery actions visually clear and safe
* avoid making raw technical notes the main visual focus

## Liquid Glass Feedback

The app has Liquid Glass styling, but many surfaces still feel like dark gray panels with borders.

Improve:

* stronger layered glass depth
* more translucency where readable
* softer edge highlights
* better hover and press states
* more intentional visual hierarchy
* less repeated identical card styling
* clearer separation between hero cards, secondary cards, controls, and diagnostics

Do not sacrifice readability.

## Mendy Feedback

Mendy is much better than before, but should feel more like a living guide.

Use Mendy contextually:

* Overview: happy or idle
* Menu Bar: thinking or guiding
* Dock & Windows: scanning or success
* Privacy: checking or success
* Advanced: thinking or neutral
* Popover: small status companion

Avoid:

* Mendy as generic decoration
* oversized square frames
* constant loops that hurt idle CPU
* too much animation

Good Mendy behavior:

* subtle page change reaction
* state-specific glow
* success pulse when everything is healthy
* thinking/scanning states only when meaningful
* Reduce Motion support

## Performance Boundary

The previous performance pass fixed a serious idle CPU issue. Do not regress this.

Do not add:

* expensive repeat-forever animations
* continuous SwiftUI layout churn
* noisy debug logging
* unnecessary timers
* new polling loops

After UI changes, verify idle CPU still settles near the improved baseline.

## Hard Boundaries

Do not touch:

* Dock preview identity logic
* Option+Tab activation or discovery logic
* performance thumbnail caches
* MenuBarItemMover
* physical menu bar movement
* bundle ID
* signing
* entitlements
* package structure
* scrolling
* MiddleClick
* Dock tuning

Do not claim:

* hidden menu bar icons are synced automatically
* menu bar physical movement works
* Thaw parity
* permissions are granted unless system checks confirm it

## Desired Next Pass

A focused UI polish and delight pass:

* slim live-status popover
* stronger Overview dashboard
* cleaner Menu Bar planning page
* better Privacy checklist
* more intentional Advanced page
* improved shared Liquid Glass system
* contextual Mendy behavior
* honest copy cleanup
* no new core features

