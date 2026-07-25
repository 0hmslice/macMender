# Mendy Integration

Mendy is now a selective product character rather than macMender's primary identity.

- App icon: the active source is `Sources/macMender/Resources/Brand/MacMenderAppIcon.png`. It depicts a modern notched MacBook with a sewn repair in its upper-right display corner. Its blue/slate lighting is tuned to stay visible in both light and dark Docks. The source is rendered into the standard app icon set, `icon.icns`, `icons/icon.icns`, and `icons/NEWICON.png`.
- Status item icon: `MacMenderBrandAssets.statusItemImage` uses an independently authored monochrome template glyph. Its modern notched MacBook silhouette carries three restrained stitches across an upper-right seam, echoing the app icon while remaining legible at the actual 22×18-point menu-bar size. It adapts automatically to light and dark menu bars and does not shrink the detailed app artwork or Mendy into an unreadable bitmap.
- Mendy appears only in onboarding Welcome and Finish. Routine pages, navigation, Overview, and the status-item popover do not load or display Mendy.
- Existing Mendy source and runtime assets remain in the repository for selective guidance, About/credits, and future approved moments.
- Menu Bar management layout chips remain removed with the deferred Menu Bar feature.

## Extending Moods

Add new states to `MendyMood`, then provide either:

- A new pose image in `Sources/macMender/Resources/Mendy`, mapped through `MendyAssets`; or
- A badge, tint, and subtle animation using the existing base pose.

Keep animations low-frequency and opt-in. Mendy should mark a meaningful moment without competing with settings or becoming the default app identity.
