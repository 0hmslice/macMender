import Foundation

/// Menu bar management in macMender is a GPL-compatible Ice/Thaw-derived subsystem.
///
/// Upstream references:
/// - Ice for macOS: https://github.com/jordanbaird/Ice
/// - Thaw: https://github.com/stonerl/Thaw
///
/// The code in this folder is not a byte-for-byte copy of either project. It adapts the
/// same architectural ideas for macMender's SwiftPM app shape:
/// - WindowServer-backed menu-bar item discovery.
/// - Stable status-item delimiters named `SItem`, `HItem`, and `AHItem`.
/// - Visible, Hidden, and Always Hidden sections computed from delimiter frames.
/// - Targeted synthetic menu-bar item movement with event-tap routing.
/// - Hover, click, scroll, timed rehide, and optional secondary-bar presentation.
enum MenuBarUpstreamAttribution {
    static let iceRepository = "https://github.com/jordanbaird/Ice"
    static let thawRepository = "https://github.com/stonerl/Thaw"
    static let iceRevision = "11edd39115f3f43a83ae114b5348df6a0e1741cf"
    static let thawRevision = "2a8301cda7fdfbabe3723442036b293b8a490504"
}
