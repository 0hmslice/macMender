# macMender Product Spec

macMender is a native macOS utility for local workflow improvements: Input, Dock previews, Window Switcher, profiles, permissions, and app behavior settings.

## Current Product Scope

1. Overview: health summary, permissions summary, Dock previews status, Window Switcher status, and a scoped status refresh action.
2. General: Launch at Login and Dock icon behavior.
3. Input: mouse, trackpad, scrolling, and MiddleClick settings.
4. Dock & Windows: Dock previews, Window Switcher, preview animation, animation duration, preview linger, and diagnostics behind disclosure.
5. Profiles: saved setups.
6. Privacy and Permissions: local privacy promise, Accessibility, Screen Recording, Input Monitoring guidance, local configuration path, and local thumbnail explanation.
7. Advanced: Safe Mode, diagnostics, recovery tools, reset onboarding, export configuration, and technical status.

## Deferred Scope

Menu Bar management is removed from the current product. There is no Menu Bar page, scanner, discovery list, hidden-area model, Command-drag tutorial, Mark to Review checklist, status-item movement, or menu-bar feature QA path.

The app still has its own macMender status item in the macOS menu bar. That status item is the app control center and is not a Menu Bar management feature.

Future Menu Bar management should be designed and verified from scratch.

## Privacy Position

- No analytics.
- No tracking.
- No remote APIs by default.
- Configuration stays local.
- Window thumbnails are used locally for previews.
- Permissions are used only for enabled features.

## Runtime Boundaries

- Dock preview display requires resolved bundle or process identity.
- Title-only Dock preview eligibility is not supported.
- Dock thumbnail capture/cache should not run during app launch.
- Option+Tab discovery and activation should remain isolated from UI polish work unless performance measurement proves it blocks startup.
- Scrolling and MiddleClick runtime behavior are separate subsystems.
