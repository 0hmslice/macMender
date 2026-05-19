# macMender Product and Engineering Spec

## 1. Product Summary

macMender is a single, local-first macOS utility for repairing small but persistent quality-of-life problems: mouse scrolling, middle-click behavior, menu bar clutter, window switching, Dock tuning, and context-based profiles.

The design goal is not to expose five separate apps inside one shell. macMender should feel like a first-party preferences app with a calm default path for normal users and precise controls for power users.

### Principles

- Privacy first: no telemetry, tracking, remote config, or background network traffic by default.
- Public APIs only: no private frameworks, no kernel extensions, no SIP changes, no driver installation.
- Safe defaults: features start conservative, reversible, and permission-scoped.
- Always-on efficiency: event taps, screen capture, and observers must suspend when unused.
- Native feel: SwiftUI-first, AppKit only where macOS integration requires it.
- Honest capability labels: features that depend on fragile OS behavior must be marked experimental.

### Target Users

- Mac users who use external mice and dislike macOS's single natural scrolling toggle.
- Power users with crowded menu bars and complex Dock/window workflows.
- Laptop users who switch between desk, mobile, presentation, and gaming contexts.
- Users who want one trustworthy local utility instead of several overlapping background apps.

## 2. Feasibility Model

macMender should classify features internally and in release planning by implementation confidence.

| Class | Meaning | Examples |
| --- | --- | --- |
| Public API feasible | Can be implemented with documented APIs and normal permissions | Profiles, settings UI, launch at login, global shortcuts, Accessibility window actions, ScreenCaptureKit previews |
| Public API best effort | Possible with documented APIs, but behavior can vary by OS version, device, or permission state | Scroll event transformation, device-specific mouse handling, window screenshots, Dock defaults editing |
| Direct distribution only | Uses public APIs but is likely too system-invasive for Mac App Store review | Modifying Dock defaults, killing/restarting Dock, overlay behavior near menu bar/Dock |
| Not currently reliable with public APIs | Should be deferred or offered as experimental only | Arbitrary global three-finger trackpad tap detection, true third-party menu bar item reordering/hiding, direct Dock icon hover integration |

This classification is important to avoid promising behavior that requires private MultitouchSupport, Dock internals, or menu extras manipulation.

## 3. Feature Domains

### 3.1 Input and Scrolling

#### User Goals

- Keep natural scrolling on the built-in trackpad while using traditional scroll direction on an external mouse.
- Make wheel scrolling smoother without adding lag or unpredictability.
- Tune vertical and horizontal scroll independently.
- Apply different behavior by app, device type, or physical device where possible.
- Use a middle-click equivalent without installing drivers.

#### MVP Features

- Global scroll profile:
  - Vertical smoothing on/off.
  - Horizontal smoothing on/off.
  - Vertical reverse on/off.
  - Horizontal reverse on/off.
  - Step size, gain, duration, and curve presets.
- Device type rules:
  - Built-in trackpad.
  - Magic Trackpad.
  - Magic Mouse.
  - External wheel mouse.
  - Unknown pointing device.
- App profile overrides:
  - Inherit global.
  - Disable smoothing for this app.
  - Override reverse direction by axis.
  - Override gain/duration.
- Safe mode switch:
  - Disable all event modification instantly from the menu bar.
  - Auto-disable if event tap is repeatedly killed by the system.
- Middle-click basics:
  - Post middle mouse click via Accessibility/CGEvent when triggered.
  - Initial triggers should favor reliable public events: configurable mouse button, keyboard+click chord, or app-specific shortcut.
  - Three-finger tap/click should be documented as experimental unless a reliable public event source is confirmed.

#### Recommended Implementation

- Use a `CGEventTap` for scroll event observation/transformation.
  - Prefer the narrowest tap location that can modify the needed events.
  - Require Accessibility permission before installing an active event tap.
  - Handle `kCGEventTapDisabledByTimeout` and `kCGEventTapDisabledByUserInput` by re-enabling once, then failing closed.
- Use `IOHIDManager` to observe pointing devices and maintain a device registry.
  - Store vendor ID, product ID, product name, transport, and stable matching hints.
  - Do not assume every scroll event can be perfectly linked to a physical device. Event metadata is limited.
- Use a deterministic smoothing engine:
  - Transform incoming wheel deltas into a short animation queue.
  - Use monotonic time and a bounded queue.
  - Cap generated events per second.
  - Cancel or coalesce on direction changes.
- Keep per-app rules keyed by bundle identifier.
  - Use `NSWorkspace.shared.frontmostApplication` and activation notifications.
  - Cache resolved rules for the current frontmost app.
- Avoid changing the system natural scrolling preference as the main behavior.
  - Directly transform scroll events instead of toggling global settings.
  - Provide a diagnostic warning if system settings conflict with expected behavior.

#### Constraints

- Public APIs do not provide a clean driver-level way to split Apple's natural scrolling setting by device.
- Exact per-physical-device mapping may be unavailable for some Bluetooth receivers, hubs, or generic mice.
- Global arbitrary multi-touch gestures are not reliably available through documented APIs. Accessibility can help post the middle-click action, but it does not by itself expose raw three-finger trackpad taps.

### 3.2 Menu Bar Management

#### User Goals

- Reduce menu bar clutter.
- Keep essential items visible.
- Reveal less important items on demand.
- Maintain different layouts for laptop and external displays when feasible.

#### Desired Model

Sections:

- Visible: always shown in the menu bar.
- Hidden: user-selected status items that stay tucked away.
- Reveal: hidden items temporarily appear when the pointer moves over Mendy in the menu bar.

#### Recommended Product Shape

Because macOS does not expose a public API for third-party apps to own, reorder, or hide other apps' status items, macMender should treat this as a best-effort/direct-distribution feature:

- Provide a menu bar organizer UI that discovers visible status items through Accessibility where possible.
- Allow users to mark discovered status items as visible or hidden.
- Implement hover-to-reveal with the least invasive technique available.
- If true hiding is not reliable on a given OS version, fall back to a guided cleanup mode:
  - Show detected menu bar apps.
  - Offer launch/open controls.
  - Help users disable items at their source app.
  - Keep non-controllable items visible with an honest explanation.

#### UI Features

- Detected item list with simple hide switches.
- Per-display layout selector:
  - Built-in display.
  - External display set.
  - Mirrored/presentation mode.
- Conflict warnings:
  - "This item is controlled by macOS and cannot be moved."
  - "This app does not expose an accessible menu bar item."
  - "Hidden behavior may reset after the app relaunches."

#### Constraints

- Third-party status-item hiding may rely on behavior outside stable documented APIs.
- System items and Control Center modules are not generally controllable.
- Menu bar overlays can conflict with Stage Manager, fullscreen spaces, multiple displays, and screen recording/privacy expectations.

### 3.3 Dock and Window Enhancements

#### User Goals

- See app windows before switching.
- Switch between windows with a faster keyboard UI than the native app switcher.
- Tune Dock behavior without remembering `defaults write` commands.
- Save Dock setups by context.

#### MVP Features

- Enhanced keyboard window switcher:
  - Default shortcut: Option+Tab, configurable.
  - Strip layout and grid layout.
  - Live or cached thumbnails where Screen Recording is granted.
  - Fallback to app icons and window titles without Screen Recording.
  - Actions: activate window, minimize, close.
- Window preview service:
  - Window list by app.
  - Thumbnail capture through ScreenCaptureKit or documented CoreGraphics window capture APIs.
  - Accessibility-based activation and window actions.
- Dock tuning panel:
  - Size.
  - Magnification.
  - Position.
  - Auto-hide.
  - Auto-hide delay.
  - Auto-hide animation speed.
  - Show indicators for open apps.
  - Show recent apps.
  - Show only running apps, if stable on the target OS.
- Live preview:
  - In-app simulated Dock preview first.
  - Explicit Apply button for actual Dock changes.
  - Reset to macOS defaults.
- Dock profiles:
  - Minimal.
  - Work.
  - Gaming.
  - Presentation.

#### Dock Hover Previews

The desired behavior is "hover over a Dock icon, show live thumbnails for that app's windows." With public APIs, macMender cannot directly plug into Dock hover events or query Dock icon hit-testing as a supported integration point.

Recommended staged approach:

1. Ship keyboard window switcher first.
2. Add optional pointer-edge previews:
   - Detect pointer near the Dock edge.
   - Show windows for the frontmost app or app under a best-effort inferred region only when confidence is high.
   - Disable automatically in fullscreen apps, games, and high pointer velocity.
3. Treat true Dock icon hover previews as experimental/direct distribution unless a robust public technique is validated.

#### Recommended Implementation

- Use `NSWorkspace` for running apps and activation changes.
- Use Accessibility APIs for window enumeration and actions:
  - `AXUIElementCreateApplication(pid)`.
  - `kAXWindowsAttribute`.
  - `kAXTitleAttribute`.
  - `kAXPositionAttribute`.
  - `kAXSizeAttribute`.
  - `kAXRaiseAction`.
  - close/minimize attributes or actions where exposed.
- Use Screen Recording permission only for thumbnails.
- Use `RegisterEventHotKey` or a modern shortcut library for global shortcut registration.
- Apply Dock settings by writing the user's Dock preferences and restarting Dock only after confirmation.
- Keep a before/after snapshot of relevant Dock preferences for reset.

#### Constraints

- Some windows do not expose useful Accessibility metadata.
- Screen Recording permission is required for actual window thumbnails.
- Spaces and fullscreen windows are only partially controllable through public APIs.
- Moving windows to another Space is not a stable public capability. Moving to another display is feasible by setting AX position/size when the app allows it.

### 3.4 Profiles, Contexts, and Automation

#### User Goals

- Switch the whole desktop behavior with one profile.
- Automatically adapt when going from laptop to desk, meeting room, game, or presentation.
- Let power users automate profile changes from scripts.

#### MVP Features

- Global profiles:
  - Input settings.
  - Window switcher settings.
  - Dock settings snapshot.
  - Menu bar layout reference, where available.
- Manual switching:
  - Preferences window.
  - Menu bar popover.
  - Optional global shortcut.
- Automatic switching:
  - Active app.
  - Display configuration.
  - Time window.
- Import/export:
  - JSON document.
  - Versioned schema.
  - Human-readable names and bundle IDs.

#### Later Features

- Wi-Fi based switching, if location/privacy tradeoffs are acceptable.
- CLI:
  - `macmender profile list`
  - `macmender profile switch Work`
  - `macmender status`
- URL scheme:
  - `macmender://profile/Work`
  - `macmender://toggle/safe-mode`
- Shortcuts action or App Intent.

#### Data Model

Use local files in Application Support rather than a remote service.

Suggested layout:

```text
~/Library/Application Support/macMender/
  config.json
  profiles/
    Work.json
    Gaming.json
    Presentation.json
  backups/
    dock-defaults-YYYYMMDD-HHMMSS.json
  logs/
    diagnostics.log
```

For a sandboxed build, these resolve inside the app container. For direct distribution, still prefer Application Support and avoid arbitrary file writes unless the user exports a config.

## 4. Information Architecture

### App Structure

macMender should be a menu bar app with a preferences window.

- `MenuBarExtra` for a simple implementation on macOS 14+.
- `NSStatusItem` with SwiftUI popover if more precise click handling is needed.
- Main preferences window opened from the menu bar icon, Dock icon disabled for normal operation.
- Optional "Show in Dock while preferences are open" behavior for accessibility and discoverability.

### Preferences Window

Use `NavigationSplitView`.

Sidebar:

1. Overview
2. Input and Scrolling
3. Menu Bar
4. Dock and Windows
5. Profiles and Automation
6. Privacy and Permissions
7. Advanced

Toolbar:

- Current profile picker.
- Safe Mode toggle.
- Search.
- Import/Export menu.
- Help/diagnostics button.

Design language:

- macOS 14-15: standard SwiftUI materials, `.regularMaterial`, system sidebars, native tables/forms.
- macOS 26+: use Liquid Glass conditionally through availability checks, with standard sidebars/toolbars first and custom `glassEffect` only for app-specific floating controls.
- Use SF Symbols for all navigation and actions.
- Keep advanced controls dense, aligned, and form-like. Avoid marketing-style panels inside preferences.

### Overview

Purpose: show app status and make the app understandable in 30 seconds.

Content:

- Current profile.
- Feature status tiles:
  - Scrolling active.
  - Menu bar management active.
  - Window switcher active.
  - Dock profile active.
- Permission health:
  - Accessibility.
  - Screen Recording.
  - Login Item.
- Last applied Dock backup.
- Quick actions:
  - Open permissions.
  - Toggle Safe Mode.
  - Reset to macOS defaults.

### Input and Scrolling

Suggested layout:

- Top segmented control: Global, Devices, Apps, Middle Click.
- Global tab:
  - Scroll direction matrix for vertical/horizontal.
  - Smoothing preset control: Off, Subtle, Balanced, Smooth, Custom.
  - Sliders for step, gain, duration.
  - Live test area with a scrollable sample pane and delta graph.
- Devices tab:
  - Table of detected pointing devices.
  - Device type badge.
  - Last seen timestamp.
  - Rule source: Global, Device Type, Device.
- Apps tab:
  - App list keyed by bundle ID.
  - Per-app overrides.
  - Add current frontmost app button.
- Middle Click tab:
  - Trigger picker.
  - Action picker.
  - Per-app overrides.
  - Experimental gesture warning where needed.

### Menu Bar

Suggested layout:

- Detected icon list with one hide/reveal switch per item.
- Current hidden count and scan status.
- Item inspector:
  - App name.
  - Bundle ID/process.
  - Detection confidence.
  - Supported actions.
- Display/Space configuration picker.
- Preview mode that shows how hover-to-reveal will behave.

Empty or degraded states should be honest:

- "macMender cannot control this item through public macOS APIs."
- "Open the owning app's settings."
- "Keep this item visible and open it from macMender instead."

### Dock and Windows

Suggested layout:

- Top segmented control: Switcher, Dock Previews, Dock Settings, Dock Profiles.
- Switcher:
  - Shortcut recorder.
  - Layout picker: Strip/Grid.
  - Thumbnail size.
  - Include minimized windows toggle.
  - Include hidden apps toggle.
- Dock Previews:
  - Hover delay.
  - Preview size.
  - Pointer-edge preview enable.
  - Experimental Dock hover toggle, disabled unless diagnostics pass.
- Dock Settings:
  - Native-looking preview of Dock.
  - Settings form.
  - Apply, Revert, Reset to macOS Defaults.
  - Show command diff for advanced users.
- Dock Profiles:
  - Profile list.
  - Save current Dock as profile.
  - Apply selected profile.

### Profiles and Automation

Suggested layout:

- Profile list.
- Profile detail inspector:
  - Bundled feature domains.
  - Included settings.
  - Last applied.
- Automation rules table:
  - Trigger.
  - Condition.
  - Profile.
  - Enabled.
- Conflict resolver:
  - Priority order.
  - Last matched rule.
  - Manual override duration.

### Privacy and Permissions

Suggested layout:

- Permission cards:
  - Accessibility: event taps, global shortcuts, window actions, middle-click posting.
  - Screen Recording: window thumbnails only.
  - Login Item: launch at login.
  - Automation/Apple Events: avoid initially unless a later feature truly requires it.
- Each card:
  - Status.
  - Why it is needed.
  - Features enabled by granting it.
  - Open System Settings button.
  - Recheck button.
- Privacy promise:
  - No analytics.
  - No tracking.
  - No remote APIs.
  - Local configuration path.
  - Optional update checking is off unless enabled.
- Diagnostics:
  - Export local diagnostic bundle.
  - Redact app/window titles option.

### Menu Bar Icon

Default click opens a compact popover:

- Current profile picker.
- Feature toggles:
  - Scrolling.
  - Window switcher.
  - Menu bar hiding.
  - Safe Mode.
- Quick status:
  - Permissions needed.
  - Active app override.
  - Current Dock profile.
- Short actions:
  - Open Preferences.
  - Export Config.
  - Quit macMender.

Right-click menu:

- Toggle Safe Mode.
- Switch Profile submenu.
- Open Preferences.
- Pause for 1 Hour.
- Quit.

Icon states:

- Normal: `wrench.and.screwdriver`.
- Safe Mode: `wrench.and.screwdriver.fill` with warning tint in popover, not a constantly colored menu bar icon.
- Permission needed: badge/dot in popover; keep menu bar subtle.

## 5. Permission and Privacy Design

### Permissions

| Permission | Needed For | Design Rule |
| --- | --- | --- |
| Accessibility | Event taps, posting middle-clicks, global window actions, AX window enumeration | Ask only when user enables a dependent feature or during explicit onboarding |
| Screen Recording | Window thumbnails and live previews | Optional; fall back to icons/titles |
| Login Item | Launch at login | User-controlled toggle using ServiceManagement |
| Input Monitoring | May be required by macOS for some global input observation paths | Explain separately if the OS prompts for it |
| Automation/Apple Events | Avoid in MVP | Add only for explicit integrations |

### Privacy Manifest

Include `PrivacyInfo.xcprivacy` with:

- `NSPrivacyTracking` false.
- Empty tracking domains.
- Empty collected data types.
- Accessed API reasons for UserDefaults or file timestamp APIs if used.

### Local Data Policy

- Store profiles locally.
- Keep logs disabled by default or minimal.
- Never log raw input events.
- Never log typed keys.
- Redact app/window titles in exportable diagnostics unless the user opts in.
- No network entitlement in the default build unless update checking is added.

## 6. Architecture

### Recommended Modules

```text
macMenderApp
  AppShell
  PreferencesWindow
  MenuBarController

Core
  ProfileStore
  RuleResolver
  PermissionState
  Diagnostics
  ConfigImportExport

InputEngine
  EventTapManager
  ScrollTransformer
  DeviceRegistry
  AppRuleMatcher
  MiddleClickService

MenuBarEngine
  MenuBarScanner
  MenuBarLayoutStore
  HiddenItemRevealPresenter

WindowEngine
  WindowEnumerator
  WindowPreviewProvider
  WindowActionService
  SwitcherOverlay

DockEngine
  DockPreferencesStore
  DockProfileStore
  DockApplyService
  DockPreviewSimulator
```

### Process Model

Start with one app process:

- Menu bar app.
- Preferences window.
- Background services in the same process.

Consider a helper later only if needed:

- Independent crash isolation for input event taps.
- Reduced memory footprint when preferences window is closed.
- More controlled launch-at-login behavior.

### State and Concurrency

- UI state: SwiftUI `@Observable` view models on the main actor.
- Long-running services: actors or dedicated queues.
- Event tap callbacks: keep minimal, non-allocating where possible, dispatch to engine queues only when necessary.
- Screen capture: throttle and cache thumbnails.
- Profile application: serialized through one `ProfileApplyCoordinator`.

### Persistence

Use JSON for user-facing import/export. Internally, either:

- JSON files for transparent local config, or
- SwiftData for richer querying plus JSON export/import.

For MVP, JSON is simpler and aligns with the privacy/export requirement.

### Testing Strategy

- Unit tests:
  - Scroll smoothing curves.
  - Rule resolution priority.
  - Profile import/export migrations.
  - Dock defaults diff generation.
- Integration tests:
  - Permission state transitions.
  - Event tap enable/disable lifecycle with mocks.
  - Window enumeration with fake AX providers.
- UI tests:
  - Preferences navigation.
  - Profile switching.
  - Permission degraded states.
- Manual system tests:
  - Intel and Apple Silicon.
  - Built-in trackpad, Magic Mouse, Magic Trackpad, Logitech/USB wheel mouse.
  - Multiple displays.
  - Stage Manager.
  - Fullscreen spaces.
  - Games/high refresh external displays.

## 7. Feature Conflicts and Safe Defaults

### Scroll Smoothing vs Games and Creative Apps

Risk: synthetic scroll smoothing can feel laggy or break apps that expect raw deltas.

Default:

- Smoothing enabled globally at a subtle preset.
- Auto-disable for known sensitive categories only after user confirmation.
- Add per-app "Raw scrolling" override.

### Scroll Reversal vs System Natural Scrolling

Risk: users can get double reversal when system settings and macMender rules interact.

Default:

- Treat system preference as the baseline.
- Show an effective direction preview for each device type.
- Never toggle the system setting automatically.

### Middle Click vs Trackpad System Gestures

Risk: three-finger gestures conflict with Look Up, Mission Control, App Expose, dragging, and accessibility gestures.

Default:

- Do not bind arbitrary three-finger tap by default until a reliable public implementation is validated.
- Use a safer trigger first, such as modifier+click or a configurable extra mouse button.
- Require per-trigger test confirmation.

### Menu Bar Management vs Other Menu Bar Tools

Risk: conflicts with Bartender, Ice, Hidden Bar, iStat Menus, BetterTouchTool, and app-specific menu extras.

Default:

- Detect known menu bar managers and show a compatibility warning.
- Disable menu bar management automatically when another manager is active unless the user opts in.
- Keep macMender's own status item stable and easy to quit.

### Dock Previews vs Window Managers

Risk: overlays and window actions can conflict with Rectangle, Magnet, Moom, yabai, Raycast, AltTab, DockDoor, and Stage Manager.

Default:

- Window switcher enabled only after explicit shortcut setup.
- Dock hover previews off by default.
- Close/move actions require hover buttons or keyboard confirmation, not accidental gestures.
- Disable previews in fullscreen games and secure input contexts.

### Dock Defaults Editing

Risk: writing Dock preferences can disrupt a user's desktop or conflict with MDM-managed settings.

Default:

- In-app simulation before applying.
- Apply button with exact changed settings.
- Backup current Dock values.
- Reset to macOS defaults and restore previous backup.
- Detect managed preferences and disable controls that cannot apply.

## 8. Rollout Plan

### MVP: Trustworthy Core

Goal: ship the smallest version that proves macMender is useful, stable, and privacy-forward.

Included:

- Menu bar app and preferences window.
- Permission center.
- Local JSON profile store.
- Input and scrolling:
  - Global scroll smoothing.
  - Per-axis reverse.
  - Device type rules.
  - Per-app raw/smoothed override.
- Middle-click:
  - Reliable configurable trigger and synthetic middle-click posting.
  - No default three-finger global gesture promise.
- Window switcher:
  - Option+Tab style switcher.
  - Icons/titles fallback.
  - Thumbnails with Screen Recording permission.
- Dock settings:
  - Read current settings.
  - Simulated preview.
  - Apply selected safe settings.
  - Backup/restore.
- Profiles:
  - Manual switch.
  - Active-app and display trigger.
- Import/export config.

Not included in MVP:

- True Dock icon hover previews.
- True third-party menu bar item hiding.
- Wi-Fi automation.
- CLI.
- Moving windows between Spaces.

### Version 1.1: Power User Expansion

- Dock profiles.
- More switcher layouts.
- Display-aware profile rules.
- Better device matching and diagnostics.
- Menu bar organizer in guided/best-effort mode.
- CLI profile switching.
- URL scheme.

### Version 1.2: Menu Bar and Preview Experiments

- Hover-to-reveal if a robust public/direct-distribution implementation is validated.
- Optional pointer-edge window previews.
- Per-display menu bar layouts where reliable.
- App-specific middle-click action presets.
- Diagnostics for compatibility with other utilities.

### Later Versions

- App Intents and Shortcuts integration.
- Wi-Fi based profile switching, designed with transparent privacy messaging.
- Advanced automation rule builder.
- Team/admin export templates.
- Optional update checker, off by default unless explicitly enabled.

## 9. Risk Register

### Permissions

Risk: users may be uncomfortable granting Accessibility and Screen Recording.

Mitigation:

- Degrade gracefully.
- Ask per feature, not at first launch.
- Explain exactly what each permission enables.
- Provide visible local-only privacy statement.
- Keep thumbnails optional.

### Performance

Risk: event taps and thumbnails can burn CPU if implemented naively.

Mitigation:

- Keep event tap callback tiny.
- Coalesce scroll events.
- Cap synthetic event rate.
- Cache thumbnails and refresh only while switcher/previews are visible.
- Stop all capture sessions when overlays close.
- Add internal performance counters visible in diagnostics.

### Apple Review

Risk: App Store review may reject or question Accessibility-driven control of other apps, Dock preference modification, event injection, or screen capture.

Mitigation:

- Primary route: Developer ID signed and notarized direct distribution.
- Keep Mac App Store plan separate as a reduced "Lite" build.
- Avoid private APIs and avoid claiming unsupported system integration.
- Provide clear user-initiated controls for system modifications.

### OS Compatibility

Risk: macOS updates can change Dock defaults, menu bar behavior, event tap handling, and Accessibility metadata.

Mitigation:

- Capability detection at runtime.
- Per-OS feature flags.
- Remote config is not allowed by privacy policy, so use local versioned compatibility tables shipped with app updates.
- Built-in diagnostics to export OS/device state.

### User Safety

Risk: a broken event tap or Dock setting could make input or desktop behavior frustrating.

Mitigation:

- Menu bar Safe Mode.
- Hold a modifier at launch to start disabled.
- Auto-disable after repeated event tap failures.
- Backup before applying Dock changes.
- Clearly visible Quit and Reset actions.

## 10. Open Product Decisions

- Distribution: direct-only first, or direct plus a reduced Mac App Store build?
- Brand line: "Fix your Mac's small annoyances" vs a more technical positioning.
- Default middle-click trigger: modifier+click, extra mouse button, or no default until configured?
- Whether to expose menu bar management in v1 as a full feature or an experimental lab.
- Whether Dock preference editing should be part of MVP or delayed until after input/window switching is stable.

## 11. Recommended First Implementation Milestones

1. Create SwiftUI app shell:
   - Menu bar extra.
   - Preferences `NavigationSplitView`.
   - Overview and Permissions pages.
2. Build config layer:
   - Versioned JSON schema.
   - Profile store.
   - Import/export.
3. Build permission state service:
   - Accessibility check and settings link.
   - Screen Recording check and settings link.
   - Login item state.
4. Build input prototype:
   - Event tap lifecycle.
   - Scroll transformer unit tests.
   - Per-app rule resolver.
5. Build window switcher prototype:
   - Shortcut registration.
   - AX window enumeration.
   - Overlay UI.
   - Thumbnail fallback behavior.
6. Build Dock preferences prototype:
   - Read current settings.
   - Generate diff.
   - Simulated preview.
   - Apply and restore flow.

This order creates visible product value early while validating the riskiest platform assumptions before investing in fragile menu bar or Dock hover behavior.
