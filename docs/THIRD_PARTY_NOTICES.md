# Third-Party Notices

## Ice for macOS

macMender's menu bar management is based on implementation research and adapted code patterns from Ice for macOS.

- Project: https://github.com/jordanbaird/Ice
- License: GNU General Public License v3.0
- Upstream revision referenced during this port: `11edd39115f3f43a83ae114b5348df6a0e1741cf`

Adapted concepts and code paths include:

- Stable menu bar section control identifiers (`SItem`, `HItem`, `AHItem`)
- Status-item section boundaries for visible, hidden, and always-hidden items
- Private WindowServer menu bar window lookup
- Targeted menu bar item event synthesis
- Event tap "scromble" routing for more reliable menu bar movement
- Frame-change verification after movement events

The project now includes GPL-3.0 licensing so these Ice-derived pieces can be shared in a license-compatible open-source release.
