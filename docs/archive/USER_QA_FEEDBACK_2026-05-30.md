# User QA Feedback - 2026-05-30

Branch tested: codex/thaw-menu-bar-rewrite

## Result

The scoped pass built successfully and improved some areas, but the core user-facing experience is not acceptable yet.

## Feedback

1. Mendy assets are too small and hard to see.
   - Mendy should not be huge, but should be more visible, expressive, and dynamic.
   - Different Mendy states should be clearly recognizable.

2. Dock window previews are still unreliable.
   - Example: hovering iMessage can show Mail because Mail is next to it.
   - Preview identity is still wrong.
   - Preview panels do not have a strong Liquid Glass effect.

3. Menu bar functionality is still not acceptable.
   - The panel UI looks decent, but the actual functionality barely works.
   - Hiding icons is unreliable.
   - Moving icons is unreliable.
   - Animations are bad and glitch between rows.
   - It does not feel smooth.
   - This needs a complete rewrite around the actual Thaw menu bar implementation, not another partial abstraction.

4. Option+Tab functionality now works much better.
   - Activation works well now.
   - But the switcher still needs stronger Liquid Glass styling and better preview polish.

## Priority

Do not move to a DockDoor pass yet.

Next pass should be:
1. Direct Thaw menu bar implementation repair/rewrite.
2. Mendy visibility and animation polish.
3. Liquid Glass treatment for Option+Tab and preview panels.
4. Dock preview identity diagnosis only, unless a safe fix is obvious.
