# Architecture

macMender is a SwiftPM macOS app with SwiftUI preferences, AppKit status-item/popup glue, local profile storage, permission checks, input event handling, Dock hover previews, and an Option+Tab window switcher.

## Current Modules

- `Sources/macMender/App`: app entry point, app model, and macMender status item controller.
- `Sources/macMender/Models`: persisted app/profile/input/window/permission models.
- `Sources/macMender/Services`: local services for permissions, login items, diagnostics, input events, Dock preferences, Dock hover, MiddleClick, window catalog, and Window Switcher.
- `Sources/macMender/Stores`: local JSON profile storage.
- `Sources/macMender/Views`: SwiftUI preferences, onboarding, popover, Mendy, and shared Liquid Glass components.
- `Sources/MultitouchSupport`: local system-library bridge for the existing MiddleClick path.

## Removed Menu Bar Management

Menu Bar management is not part of the current runtime. The Menu Bar page, scanner, Thaw-port engine target, menu-bar XPC helper, management views, models, and tests were removed in the `codex/remove-menubar-and-polish-settings` pass.

The app's own macMender menu bar status item remains. It is the control center for opening Settings, checking permissions, and quitting.
