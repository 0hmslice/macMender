# Mendy Integration

Mendy is treated as a product character, not only an icon.

- App icon: `NEWICON.png` is processed into `icon.icns` for the SwiftPM-built app bundle. The same source is mirrored into `Sources/macMender/Resources/Assets.xcassets/AppIcon.appiconset` so an Xcode target can use the standard macOS app icon set.
- Menu bar icon: `MendyMenuBarTemplate.png` is a compact template-capable silhouette generated from the clean robot head and used by `MendyMenuBarIconView` in `MenuBarExtra`.
- UI avatar: `MendyAvatarView` renders the clean robot-head asset `MendyRobotHead.png` on a glass surface and decorates that base pose with SF Symbol badges for moods. The square app icon background is intentionally not used inside the app UI.

## Extending Moods

Add new states to `MendyMood`, then provide either:

- A new pose image in `Sources/macMender/Resources/Mendy`, mapped through `MendyAssets`; or
- A badge, tint, and subtle animation using the existing base pose.

Keep animations low-frequency and opt-in. Mendy should confirm app state and reduce confusion without competing with the settings controls.
