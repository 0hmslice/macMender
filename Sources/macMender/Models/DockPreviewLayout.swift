import CoreGraphics

/// Screen edge the Dock sits on.
enum DockEdge: String, Sendable, Equatable {
    case bottom
    case left
    case right

    var isHorizontal: Bool { self == .bottom }
}

/// Positions of the window cards inside a Dock preview.
///
/// Pure geometry, so the panel can be sized before it is shown and the same numbers drive the
/// view. Card frames use a top-left origin inside the preview's content area.
struct DockPreviewLayout: Equatable, Sendable {
    enum Metrics {
        static let contentPadding: CGFloat = 10
        static let cardPadding: CGFloat = 6
        static let cardSpacing: CGFloat = 4
        static let titleHeight: CGFloat = 22
        static let footerHeight: CGFloat = 22
        static let minimumThumbnailHeight: CGFloat = 84
        static let minimumAspectRatio: CGFloat = 0.72
        static let maximumAspectRatio: CGFloat = 1.9
        /// Space between the Dock and the preview.
        static let dockGap: CGFloat = 8
        static let screenMargin: CGFloat = 12
    }

    var cardFrames: [CGRect]
    var thumbnailSizes: [CGSize]
    var contentSize: CGSize
    var thumbnailHeight: CGFloat
    /// Windows that did not fit even at the smallest size.
    var hiddenCount: Int

    static func thumbnailSize(aspectRatio: CGFloat, height: CGFloat) -> CGSize {
        let ratio = min(max(aspectRatio, Metrics.minimumAspectRatio), Metrics.maximumAspectRatio)
        return CGSize(width: (height * ratio).rounded(), height: height)
    }

    /// Largest content area a preview may occupy on a screen.
    static func maximumContentSize(screenSize: CGSize, edge: DockEdge) -> CGSize {
        if edge.isHorizontal {
            return CGSize(width: screenSize.width - Metrics.screenMargin * 2, height: screenSize.height * 0.62)
        }
        return CGSize(width: screenSize.width * 0.62, height: screenSize.height - Metrics.screenMargin * 2)
    }

    static func compute(
        aspectRatios: [CGFloat],
        thumbnailHeight requestedHeight: CGFloat,
        showTitles: Bool,
        edge: DockEdge,
        maximumContentSize: CGSize
    ) -> DockPreviewLayout {
        guard !aspectRatios.isEmpty else {
            return DockPreviewLayout(cardFrames: [], thumbnailSizes: [], contentSize: .zero, thumbnailHeight: requestedHeight, hiddenCount: 0)
        }

        // Shrink thumbnails before hiding any window.
        var height = max(requestedHeight, Metrics.minimumThumbnailHeight)
        while true {
            if let layout = arrange(aspectRatios, height: height, showTitles: showTitles, edge: edge, limit: maximumContentSize, hiddenCount: 0) {
                return layout
            }
            guard height > Metrics.minimumThumbnailHeight else { break }
            height = max(Metrics.minimumThumbnailHeight, (height * 0.88).rounded(.down))
        }

        var visibleCount = aspectRatios.count - 1
        while visibleCount > 1 {
            let limit = CGSize(width: maximumContentSize.width, height: maximumContentSize.height - Metrics.footerHeight)
            if let layout = arrange(
                Array(aspectRatios.prefix(visibleCount)),
                height: height,
                showTitles: showTitles,
                edge: edge,
                limit: limit,
                hiddenCount: aspectRatios.count - visibleCount
            ) {
                return layout
            }
            visibleCount -= 1
        }

        // A single card always shows, even on a very small screen.
        return arrange(
            Array(aspectRatios.prefix(1)),
            height: height,
            showTitles: showTitles,
            edge: edge,
            limit: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            hiddenCount: aspectRatios.count - 1
        )!
    }

    enum Direction: Sendable {
        case left, right, up, down
    }

    /// The card reached by an arrow key. Moves to the nearest card in that direction; along a
    /// line of cards the selection wraps from the last card to the first and back.
    func cardIndex(from current: Int?, moving direction: Direction, edge: DockEdge) -> Int? {
        guard !cardFrames.isEmpty else { return nil }
        guard let current, cardFrames.indices.contains(current) else {
            return direction == .left || direction == .up ? cardFrames.count - 1 : 0
        }

        let origin = CGPoint(x: cardFrames[current].midX, y: cardFrames[current].midY)
        var best: (index: Int, cost: CGFloat)?
        for (index, frame) in cardFrames.enumerated() where index != current {
            let dx = frame.midX - origin.x
            let dy = frame.midY - origin.y
            let (forward, sideways): (CGFloat, CGFloat)
            switch direction {
            case .left: (forward, sideways) = (-dx, abs(dy))
            case .right: (forward, sideways) = (dx, abs(dy))
            case .up: (forward, sideways) = (-dy, abs(dx))
            case .down: (forward, sideways) = (dy, abs(dx))
            }
            // Only cards mostly in the requested direction count.
            guard forward > 1, sideways <= forward * 2 else { continue }
            let cost = forward + sideways * 2
            if best == nil || cost < best!.cost {
                best = (index, cost)
            }
        }
        if let best { return best.index }

        let movesAlongLine = edge.isHorizontal
            ? direction == .left || direction == .right
            : direction == .up || direction == .down
        guard movesAlongLine, cardFrames.count > 1 else { return current }
        let step = direction == .left || direction == .up ? -1 : 1
        return (current + step + cardFrames.count) % cardFrames.count
    }

    /// Lays cards out in lines running along the Dock: rows for a bottom Dock, columns for a side Dock.
    private static func arrange(
        _ aspectRatios: [CGFloat],
        height: CGFloat,
        showTitles: Bool,
        edge: DockEdge,
        limit: CGSize,
        hiddenCount: Int
    ) -> DockPreviewLayout? {
        let thumbnails = aspectRatios.map { thumbnailSize(aspectRatio: $0, height: height) }
        let cardSizes = thumbnails.map { thumbnail in
            CGSize(
                width: thumbnail.width + Metrics.cardPadding * 2,
                height: thumbnail.height + Metrics.cardPadding * 2 + (showTitles ? Metrics.titleHeight : 0)
            )
        }
        let horizontal = edge.isHorizontal
        func along(_ size: CGSize) -> CGFloat { horizontal ? size.width : size.height }
        func across(_ size: CGSize) -> CGFloat { horizontal ? size.height : size.width }

        let padding = Metrics.contentPadding * 2
        let alongLimit = along(limit) - padding
        let acrossLimit = across(limit) - padding
        guard let lines = lines(for: cardSizes.map(along), limit: alongLimit) else { return nil }

        func lineLength(_ line: Range<Int>) -> CGFloat {
            line.reduce(0) { $0 + along(cardSizes[$1]) } + Metrics.cardSpacing * CGFloat(line.count - 1)
        }
        let lineThickness = lines.map { line in line.map { across(cardSizes[$0]) }.max() ?? 0 }
        let totalAcross = lineThickness.reduce(0, +) + Metrics.cardSpacing * CGFloat(lines.count - 1)
        guard totalAcross <= acrossLimit else { return nil }
        let longest = lines.map(lineLength).max() ?? 0

        var frames = [CGRect](repeating: .zero, count: cardSizes.count)
        var acrossOffset = Metrics.contentPadding
        for (lineIndex, line) in lines.enumerated() {
            var alongOffset = Metrics.contentPadding + ((longest - lineLength(line)) / 2).rounded()
            for index in line {
                let size = cardSizes[index]
                let acrossInset = ((lineThickness[lineIndex] - across(size)) / 2).rounded()
                frames[index] = horizontal
                    ? CGRect(x: alongOffset, y: acrossOffset + acrossInset, width: size.width, height: size.height)
                    : CGRect(x: acrossOffset + acrossInset, y: alongOffset, width: size.width, height: size.height)
                alongOffset += along(size) + Metrics.cardSpacing
            }
            acrossOffset += lineThickness[lineIndex] + Metrics.cardSpacing
        }

        let footer = hiddenCount > 0 ? Metrics.footerHeight : 0
        let contentSize = horizontal
            ? CGSize(width: longest + padding, height: totalAcross + padding + footer)
            : CGSize(width: totalAcross + padding, height: longest + padding + footer)
        return DockPreviewLayout(
            cardFrames: frames,
            thumbnailSizes: thumbnails,
            contentSize: contentSize,
            thumbnailHeight: height,
            hiddenCount: hiddenCount
        )
    }

    /// Splits cards into lines no longer than `limit`, preferring evenly filled lines over one
    /// full line followed by a nearly empty one.
    private static func lines(for lengths: [CGFloat], limit: CGFloat) -> [Range<Int>]? {
        guard lengths.allSatisfy({ $0 <= limit }) else { return nil }

        func fits(_ line: Range<Int>) -> Bool {
            line.reduce(0) { $0 + lengths[$1] } + Metrics.cardSpacing * CGFloat(line.count - 1) <= limit
        }

        var greedy = [Range<Int>]()
        var start = 0
        for index in lengths.indices where !fits(start..<(index + 1)) {
            greedy.append(start..<index)
            start = index
        }
        greedy.append(start..<lengths.count)
        guard greedy.count > 1 else { return greedy }

        let perLine = Int((Double(lengths.count) / Double(greedy.count)).rounded(.up))
        let balanced = stride(from: 0, to: lengths.count, by: perLine).map { $0..<min($0 + perLine, lengths.count) }
        return balanced.count == greedy.count && balanced.allSatisfy(fits) ? balanced : greedy
    }
}

/// Where a preview sits relative to its Dock icon. Rectangles use AppKit screen coordinates
/// (origin at the bottom left).
enum DockPreviewPlacement {
    static func contentFrame(
        contentSize: CGSize,
        iconFrame: CGRect,
        dockFrame: CGRect,
        edge: DockEdge,
        screenFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGRect {
        let margin = DockPreviewLayout.Metrics.screenMargin
        let gap = DockPreviewLayout.Metrics.dockGap
        func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            upper < lower ? lower : min(max(value, lower), upper)
        }

        let origin: CGPoint
        switch edge {
        case .bottom:
            let dockTop = dockFrame.isEmpty ? iconFrame.maxY : max(dockFrame.maxY, iconFrame.maxY)
            origin = CGPoint(
                x: clamp(iconFrame.midX - contentSize.width / 2, screenFrame.minX + margin, screenFrame.maxX - contentSize.width - margin),
                y: clamp(dockTop + gap, screenFrame.minY + margin, visibleFrame.maxY - contentSize.height - margin)
            )
        case .left:
            let dockSide = dockFrame.isEmpty ? iconFrame.maxX : max(dockFrame.maxX, iconFrame.maxX)
            origin = CGPoint(
                x: clamp(dockSide + gap, screenFrame.minX + margin, screenFrame.maxX - contentSize.width - margin),
                y: clamp(iconFrame.midY - contentSize.height / 2, screenFrame.minY + margin, visibleFrame.maxY - contentSize.height - margin)
            )
        case .right:
            let dockSide = dockFrame.isEmpty ? iconFrame.minX : min(dockFrame.minX, iconFrame.minX)
            origin = CGPoint(
                x: clamp(dockSide - gap - contentSize.width, screenFrame.minX + margin, screenFrame.maxX - contentSize.width - margin),
                y: clamp(iconFrame.midY - contentSize.height / 2, screenFrame.minY + margin, visibleFrame.maxY - contentSize.height - margin)
            )
        }
        return CGRect(origin: origin, size: contentSize)
    }
}

/// The region the pointer may occupy without dismissing a preview: the preview, its Dock icon,
/// and a corridor fanning out from the icon's middle to the preview's near edge. The corridor lets
/// the pointer cut diagonally across neighboring icons on its way to a distant card, while a
/// pointer sliding along the lower half of the Dock is outside it and switches previews at once.
struct DockPreviewSafeZone: Equatable, Sendable {
    var iconFrame: CGRect
    var contentFrame: CGRect
    var edge: DockEdge

    private static let contentSlack: CGFloat = 8
    private static let iconSlack: CGFloat = 6
    /// Extends the icon toward the screen edge so resting at the very edge still counts.
    private static let edgeReach: CGFloat = 48

    func contains(_ point: CGPoint) -> Bool {
        let content = contentFrame.insetBy(dx: -Self.contentSlack, dy: -Self.contentSlack)
        let icon = iconFrame.insetBy(dx: -Self.iconSlack, dy: -Self.iconSlack)
        let reach: CGRect
        switch edge {
        case .bottom:
            reach = CGRect(x: icon.minX, y: icon.minY - Self.edgeReach, width: icon.width, height: icon.height + Self.edgeReach)
        case .left:
            reach = CGRect(x: icon.minX - Self.edgeReach, y: icon.minY, width: icon.width + Self.edgeReach, height: icon.height)
        case .right:
            reach = CGRect(x: icon.minX, y: icon.minY, width: icon.width + Self.edgeReach, height: icon.height)
        }
        return content.contains(point) || reach.contains(point) || isInCorridor(point)
    }

    /// Whether the pointer is between the icon and the preview without being on either.
    func isInCorridor(_ point: CGPoint) -> Bool {
        let content = contentFrame.insetBy(dx: -Self.contentSlack, dy: -Self.contentSlack)
        let icon = iconFrame.insetBy(dx: -Self.iconSlack, dy: -Self.iconSlack)
        let vertices: [CGPoint]
        switch edge {
        case .bottom:
            vertices = [
                CGPoint(x: icon.minX, y: icon.midY),
                CGPoint(x: icon.maxX, y: icon.midY),
                CGPoint(x: content.maxX, y: content.minY),
                CGPoint(x: content.minX, y: content.minY)
            ]
        case .left:
            vertices = [
                CGPoint(x: icon.midX, y: icon.maxY),
                CGPoint(x: icon.midX, y: icon.minY),
                CGPoint(x: content.minX, y: content.minY),
                CGPoint(x: content.minX, y: content.maxY)
            ]
        case .right:
            vertices = [
                CGPoint(x: icon.midX, y: icon.minY),
                CGPoint(x: icon.midX, y: icon.maxY),
                CGPoint(x: content.maxX, y: content.maxY),
                CGPoint(x: content.maxX, y: content.minY)
            ]
        }
        return Self.convexPolygon(vertices, contains: point)
    }

    private static func convexPolygon(_ vertices: [CGPoint], contains point: CGPoint) -> Bool {
        var sign: CGFloat = 0
        for index in vertices.indices {
            let a = vertices[index]
            let b = vertices[(index + 1) % vertices.count]
            let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            guard cross != 0 else { continue }
            if sign == 0 {
                sign = cross > 0 ? 1 : -1
            } else if (cross > 0) != (sign > 0) {
                return false
            }
        }
        return true
    }
}

/// Where the full-size view of a window appears while the pointer rests on its card.
enum DockPreviewPeekPlacement {
    /// - Parameters:
    ///   - windowFrame: The window's real frame in AppKit screen coordinates, when it is
    ///     currently visible on screen; `nil` for minimized, hidden, and other-Space windows.
    ///   - windowSize: The window's size in points.
    ///   - visibleFrame: The usable area of the screen showing the preview.
    static func frame(windowFrame: CGRect?, windowSize: CGSize, visibleFrame: CGRect) -> CGRect {
        if let windowFrame, visibleFrame.intersects(windowFrame) {
            return windowFrame
        }
        guard windowSize.width > 1, windowSize.height > 1 else { return .zero }
        let limit = CGSize(width: visibleFrame.width * 0.8, height: visibleFrame.height * 0.8)
        let scale = min(1, limit.width / windowSize.width, limit.height / windowSize.height)
        let size = CGSize(width: (windowSize.width * scale).rounded(), height: (windowSize.height * scale).rounded())
        return CGRect(
            x: (visibleFrame.midX - size.width / 2).rounded(),
            y: (visibleFrame.midY - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        )
    }
}
