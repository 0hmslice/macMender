# macMender UI Rebrand Research

Date: July 24, 2026

Target environment: macOS 27.0 build 26A5388g

Branch: `codex/macos27-ui-rebrand`

## Direction

macMender will become a calm, precise Mac utility with native structure, quiet content surfaces, functional Liquid Glass, and small moments of warmth. The redesign changes presentation and view composition without changing feature meaning or rewriting working runtime systems.

The chosen architecture is:

- `NavigationSplitView` with a native `List(selection:)` sidebar for peer destinations.
- A restrained native toolbar for the global profile switcher and only genuinely global actions.
- One coherent semantic detail background, with `Form`, `Section`, `LabeledContent`, native lists, tables, pickers, toggles, sliders, disclosures, and button roles wherever they fit.
- Liquid Glass primarily in navigation, toolbar controls, popovers, floating controls, and overlays. Ordinary settings content uses opaque or lightly material-backed semantic surfaces.
- macOS 14 remains the deployment floor. macOS 26 and 27 visual refinements are availability-gated and have a clean earlier-system fallback.

## Apple principles relevant to macMender

1. Treat macMender as a utility app with stable navigation, not as a collection of independent mascot panels. Its Overview, live status, profiles, previews, diagnostics, and onboarding support a persistent sidebar shell.
2. Let the system own sidebar selection, toolbar integration, focus, accent color, window activation, inactive-window appearance, and accessibility adaptation.
3. Keep controls close to what they change. Put high-value information first, align labels and values, and progressively disclose technical detail.
4. Use Liquid Glass as a functional layer above content. Do not stack glass on glass or place settings text over clear glass.
5. Prefer native controls and semantic colors. Pair every status color with text and a symbol.
6. Use motion to explain state or acknowledge an action. Avoid decorative motion and any animation that consumes resources at idle.
7. Build accessibility into the component system: VoiceOver, keyboard focus, Increase Contrast, Reduce Transparency, Reduce Motion, Differentiate Without Color, and Show Borders all need intentional behavior.
8. Design for resizable Mac windows and practical information density. Essential actions must not depend on the bottom edge remaining visible.

macOS 27 refines standard sidebar and toolbar presentation, selection emphasis, content extension, toolbar overflow, and interactive glass. Native architecture should receive these improvements automatically. Any macOS 27-only API remains beta-sensitive and must be narrowly availability-gated.

## Patterns worth adopting

- Native sidebar, toolbar, content, and inspector relationships.
- One dominant purpose per page.
- Compact page introductions rather than decorative heroes.
- Native form rows with concise secondary explanations.
- Status labels that combine a semantic symbol, text, and color.
- Progressive disclosure for diagnostics, paths, and implementation boundaries.
- Compact, task-focused popovers rather than miniature settings windows.
- Short, interruptible state transitions and subtle hover feedback.
- Keyboard navigation, familiar shortcuts, and visible standard focus rings.
- Empty and success states that are useful first and delightful second.

## Patterns to avoid

- Glass on every content card or nested translucent panels.
- Broad decorative gradients, glowing borders, and shadows used as hierarchy.
- A mascot as the persistent source of page identity or system status.
- A hand-built sidebar that duplicates native list selection.
- Horizontal icon or segmented navigation for a large hierarchy when a list is clearer.
- A crowded toolbar containing navigation, status, profile, and page actions at once.
- Always-visible diagnostic density.
- Bespoke toggles, sliders, menus, selection highlights, and confirmation UI when native controls work.
- Color-only status communication.
- Repeat-forever decorative animation.
- Copying the layout, brand colors, artwork, iconography, or voice of another app.

## Current macMender UI problems

- Mendy appears in the sidebar and most page headers, making the whole app mascot-led rather than selectively warm.
- The sidebar combines a mascot header, custom button rows, and a persistent service block. This fights the standard sidebar hierarchy and consumes space without improving navigation.
- Most content is wrapped in custom translucent cards. The detail gradient, glass cards, nested material rows, strokes, and shadows blur the distinction between navigation and content.
- Overview uses a large mascot hero and four equal-height feature cards even when only one item needs attention.
- Input and Dock & Windows each place broad feature areas behind segmented controls, which reduces scanability and makes page state less obvious.
- Profiles is composed as stacked cards instead of a native selected collection with direct actions.
- Privacy repeats the local-privacy promise at large scale before the actionable permission list.
- Advanced exposes substantial technical material rather than leading with configuration and recovery and disclosing diagnostics on demand.
- The largest UI files are difficult to change safely: Onboarding is 876 lines, Input is 504, Overview is 415, Dock & Windows is 398, and Advanced is 373.
- Fixed card, onboarding-rail, guide, and popover dimensions create clipping risk when text size or localization changes.
- Custom glass surfaces use fixed radii, highlights, white strokes, gradients, and shadows that do not consistently adapt to Reduce Transparency, Increase Contrast, Differentiate Without Color, or Show Borders.
- Normal page rendering can load or animate Mendy even when no mascot moment is needed.
- Every major page observes the aggregate `AppModel`; changes forwarded from its runtime services can invalidate much more of the view tree than the visible state requires. The rebrand will avoid adding more polling or broad observation while preserving current ownership.

## Proposed design system

The shared visual system will define:

- Spacing tokens for compact, standard, section, and page rhythm.
- A small set of system-aligned corner radii.
- Semantic typography roles for page title, section title, row label, description, status, and technical detail.
- Semantic status roles: active, attention, paused, unavailable, and neutral. Each role always includes text and a symbol in addition to color.
- `PageHeader`, `SettingsSection`, `SettingsRow`, `StatusLabel`, `Callout`, `EmptyState`, `ConfirmationState`, and compact toolbar controls.
- Functional glass surfaces for navigation, popovers, overlays, and selected floating controls.
- Quiet content surfaces based on semantic system colors and materials.
- Standard hover, pressed, focus, selection, and motion behavior.
- Explicit Reduce Transparency, Increase Contrast, Show Borders, Differentiate Without Color, and Reduce Motion fallbacks.

The existing `AppModel`, configuration bindings, service actions, and result models remain the source of truth. View refactoring must not change their behavior.

## Page-by-page plan

### App shell

- Replace the custom button sidebar with `List(selection:)` and native labels.
- Remove the Mendy sidebar header and decorative bottom service block.
- Keep the profile switcher in the toolbar as a global, frequent control.
- Use one coherent background and let the system provide sidebar and toolbar glass.

### Overview

- Replace the mascot hero with a compact health summary and current-profile context.
- Prioritize attention-required actions; keep healthy states concise.
- Reduce the number of equal visual modules and remove filler.

### General

- Use a native settings form for launch-at-login and Dock-icon behavior.
- Clearly label these as app-wide settings.

### Input

- Make global scroll behavior, device rules, app overrides, and Three-Finger Tap easy to locate and understand.
- Clearly distinguish mouse and trackpad direction behavior.
- Keep a lightweight interaction preview only if it remains idle-cost-free.

### Dock & Windows

- Present Window Switcher and Dock Previews as clearly separate feature groups.
- Keep Dock preference changes explicit and recoverable.
- Put discovery diagnostics behind a disclosure.
- Preserve all existing runtime and interaction logic.

### Menu Bar Spacing

- Present one focused spacing utility with presets, custom slider, Apply, Reset, and an illustrative preview if it stays inexpensive.
- Keep the macOS compatibility result prominent and truthful.
- Never imply individual-item management.

### Profiles

- Use a native list or table with an obvious current selection.
- Provide create, switch, rename, duplicate, and delete affordances without changing profile semantics.
- Explain profile-specific versus app-wide settings near the collection.

### Privacy

- Lead with the permission list, current status, reason, and action for each permission.
- Keep the local privacy promise compact.
- Move paths and technical data use into a disclosure.

### Advanced

- Group configuration, recovery, and diagnostics clearly.
- Separate destructive actions visually and use correct button roles.
- Hide runtime boundaries and detailed diagnostics by default.

### Onboarding

- Preserve the existing multi-step flow, permission truth, and drag-to-add instructions.
- Keep Mendy only for Welcome and/or Finish.
- Use SF Symbols, diagrams, and native permission rows for other steps.

### Status item popover

- Show one running or attention summary, essential feature states, Open macMender, conditional Permissions, and a lower-priority Quit action.
- Remove Mendy unless a tiny static mark proves materially useful.

### Dock preview and Option+Tab overlays

- Preserve identity, activation, filtering, context-menu, and Escape behavior.
- Refine only the visual surface, hierarchy, and focus/selection clarity.

## Mendy retirement plan

Mendy will be removed from:

- the sidebar;
- routine page headers;
- ordinary status cards;
- Profiles creation guidance;
- Privacy presentation;
- Dock diagnostics;
- the regular status-item popover.

Mendy assets will not be deleted. The loader will remain lazy, and Mendy may appear only in Welcome or Finish onboarding, one meaningful empty/success/recoverable-error state, About/credits, or one optional subtle easter egg. No mascot animation will run during ordinary page rendering.

## Accessibility plan

- Prefer native roles and controls so VoiceOver, keyboard navigation, focus rings, and system appearance adaptations work by default.
- Add concise labels, values, and hints where the visible label does not fully describe the control.
- Preserve logical reading order and whole-row selection behavior.
- Keep technical and error text selectable.
- Use practical hit targets and avoid unlabeled icon-only actions.
- Never rely on color, opacity, position, translucency, or motion alone.
- Replace translucent custom surfaces with sufficiently opaque semantic backgrounds under Reduce Transparency.
- Strengthen boundaries and symbols for Increase Contrast, Show Borders, and Differentiate Without Color.
- Remove spatial, spring, or repetitive movement under Reduce Motion; use a short fade or immediate state change.

## Performance plan

- Remove repeat-forever mascot motion from normal pages.
- Avoid compositor-heavy nested materials and continuous visual effects.
- Keep illustrations and Mendy assets lazy and local to the few views that use them.
- Split oversized views along feature boundaries while keeping state ownership stable.
- Avoid repeated running-application enumeration and app-icon resolution during ordinary body evaluation where a local refresh or cache is sufficient.
- After each milestone, run `swift build`, `swift test`, package verification, and the packaged app.
- Exercise page switching, popover, Dock previews, and Option+Tab after each relevant milestone.
- Sample idle CPU with the window closed and on each page, and inspect memory after thumbnail-heavy use.
- Reject any design that introduces a persistent update loop, sustained idle CPU, or material memory growth.

## Implementation order and risks

Order:

1. Shared visual system.
2. App shell and navigation.
3. Overview, General, and Input.
4. Dock & Windows and Menu Bar Spacing.
5. Profiles, Privacy, and Advanced.
6. Onboarding, status-item popover, and overlays.
7. Accessibility, performance, and full regression QA.

Primary risks:

- Accidentally changing a runtime binding while splitting large views.
- Losing navigation selection or toolbar behavior across macOS 14 through 27.
- Making status presentation prettier but less truthful.
- Applying new glass APIs too broadly or without availability checks.
- Disturbing Dock preview identity, Finder filtering, context-menu suppression, Option+Tab activation, or Escape behavior while restyling overlays.

These risks are controlled through small commits, build/test/package gates, packaged-app inspection, and keeping runtime service files outside the visual refactor unless a narrow UI binding fix is proven necessary.

## Research sources

Apple guidance:

- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
- [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)
- [Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/)
- [Modernize your AppKit app](https://developer.apple.com/videos/play/wwdc2026/289/)
- [What is new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/)
- [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)

Apple Design Awards:

- [2024 winners and finalists](https://developer.apple.com/design/awards/2024/)
- [2025 winners and finalists](https://developer.apple.com/design/awards/2025/)
- [2026 winners and finalists](https://developer.apple.com/design/awards/)

Award-derived lessons include Crouton's hierarchy, Bears Gratitude's selective character use, Play's approachable complexity, iA Writer's restrained chrome, puffies.' accessibility variants, Moonlitt's simple onboarding and integrated glass, Structured's scanability, Guitar Wiz's accessibility depth, Tide Guide's clear dense information, and grug's small edge details without extraneous features.

Current Mac-app references inspected for behavior and hierarchy only:

- [Raycast for Mac v2](https://manual.raycast.com/new-in-v2)
- [Little Snitch](https://www.obdev.at/products/littlesnitch/)
- [CleanShot X](https://cleanshot.com/features)
- [Things](https://culturedcode.com/things/features/)
- [Pixelmator Pro](https://www.apple.com/pixelmator-pro/)
- [Nova](https://help.panic.com/nova/editor/)

No external layout, artwork, icon, palette, identity, or marketing copy will be copied.
