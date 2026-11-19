import CoreGraphics

struct WindowSwitcherPresentationMetrics: Equatable {
    var panelSize: CGSize
    var thumbnailSize: CGFloat
    var gridColumnCount: Int

    static func calculate(
        layout: SwitcherLayout,
        windowCount: Int,
        requestedThumbnailSize: CGFloat,
        visibleSize: CGSize
    ) -> Self {
        switch layout {
        case .strip:
            stripMetrics(
                windowCount: windowCount,
                requestedThumbnailSize: requestedThumbnailSize,
                visibleSize: visibleSize
            )
        case .grid:
            gridMetrics(
                windowCount: windowCount,
                requestedThumbnailSize: requestedThumbnailSize,
                visibleSize: visibleSize
            )
        }
    }

    private static func stripMetrics(
        windowCount: Int,
        requestedThumbnailSize: CGFloat,
        visibleSize: CGSize
    ) -> Self {
        let count = max(windowCount, 1)
        let maximumWidth = visibleSize.width * 0.82
        let maximumHeight = visibleSize.height * 0.42
        let thumbnail = min(max(requestedThumbnailSize, 112), 196)
        let cardWidth = thumbnail + 12
        let spacing: CGFloat = 10
        let horizontalPadding: CGFloat = 32
        let verticalChrome: CGFloat = 88
        let desiredWidth = cardWidth * CGFloat(count)
            + spacing * CGFloat(max(count - 1, 0))
            + horizontalPadding
        let minimumWidth: CGFloat = 420
        let desiredHeight = thumbnail * 0.68 + verticalChrome

        return Self(
            panelSize: CGSize(
                width: min(maximumWidth, max(desiredWidth, minimumWidth)),
                height: min(maximumHeight, max(desiredHeight, 220))
            ),
            thumbnailSize: thumbnail,
            gridColumnCount: count
        )
    }

    private static func gridMetrics(
        windowCount: Int,
        requestedThumbnailSize: CGFloat,
        visibleSize: CGSize
    ) -> Self {
        let maximumWidth = visibleSize.width * 0.72
        let maximumHeight = visibleSize.height * 0.72
        let count = max(windowCount, 1)
        let maximumColumns = 5
        let preferredColumns = Int(ceil(sqrt(Double(count))))
        let columns = max(1, min(maximumColumns, preferredColumns))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let spacing: CGFloat = 12
        let horizontalPadding: CGFloat = 36
        let verticalPadding: CGFloat = 76
        let cardChrome: CGFloat = 22
        let cardFooter: CGFloat = 58
        let preferredThumbnail = min(requestedThumbnailSize, 168)
        let availableCardWidth = (
            maximumWidth - horizontalPadding - spacing * CGFloat(max(columns - 1, 0))
        ) / CGFloat(columns)
        let availableCardHeight = (
            maximumHeight - verticalPadding - spacing * CGFloat(max(rows - 1, 0))
        ) / CGFloat(rows)
        let thumbnail = max(
            92,
            min(preferredThumbnail, availableCardWidth - cardChrome, (availableCardHeight - cardFooter) / 0.68)
        )
        let cardWidth = thumbnail + cardChrome
        let cardHeight = thumbnail * 0.68 + cardFooter
        let width = cardWidth * CGFloat(columns)
            + spacing * CGFloat(max(columns - 1, 0))
            + horizontalPadding
        let height = cardHeight * CGFloat(rows)
            + spacing * CGFloat(max(rows - 1, 0))
            + verticalPadding

        return Self(
            panelSize: CGSize(
                width: min(maximumWidth, max(width, 520)),
                height: min(maximumHeight, max(height, 360))
            ),
            thumbnailSize: thumbnail,
            gridColumnCount: columns
        )
    }
}
