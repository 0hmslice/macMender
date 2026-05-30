# Mendy Integration

Mendy is treated as a product character, not only an icon.

- App icon: `NEWICON.png` is processed into `icon.icns` for the SwiftPM-built app bundle. The same source is mirrored into `Sources/macMender/Resources/Assets.xcassets/AppIcon.appiconset` so an Xcode target can use the standard macOS app icon set.
- Menu bar icon: the current status-item source art lives in the project root at `menubar icons/`. It is processed into `Sources/macMender/Resources/Assets.xcassets/MendyStatusItem.imageset` as a template-capable 1x/2x/3x image set and loaded through `MendyAssets.menuBarTemplate`. A raw fallback copy also lives at `Sources/macMender/Resources/Mendy/MendyStatusItem.png` for SwiftPM/test resource lookup. To tweak the status icon, replace the root raster source and regenerate both outputs.
- Menu Bar Layout chip: Mendy uses the same live ScreenCaptureKit status-window snapshot pipeline as other menu-bar items, so the lane chip reflects the actual status icon on screen. It only falls back to the Mendy status asset when a live snapshot is unavailable.
- UI avatar: `MendyAvatarView` renders the clean robot-head asset `MendyRobotHead.png` on a glass surface and decorates that base pose with SF Symbol badges for moods. The square app icon background is intentionally not used inside the app UI.

## Extending Moods

Add new states to `MendyMood`, then provide either:

- A new pose image in `Sources/macMender/Resources/Mendy`, mapped through `MendyAssets`; or
- A badge, tint, and subtle animation using the existing base pose.

Keep animations low-frequency and opt-in. Mendy should confirm app state and reduce confusion without competing with the settings controls.
