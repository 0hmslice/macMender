import AppKit

/// An independently authored, monochrome menu-bar glyph that carries the
/// MacBook-and-mending identity without shrinking the detailed app icon.
enum MacMenderStatusIcon {
    static let size = NSSize(width: 22, height: 18)

    static func makeImage() -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            drawDisplay()
            drawBase()
            drawMendingMark()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "macMender"
        return image
    }

    private static func drawDisplay() {
        let outline = NSBezierPath()
        outline.move(to: NSPoint(x: 2.4, y: 5.1))
        outline.line(to: NSPoint(x: 2.4, y: 13.7))
        outline.curve(
            to: NSPoint(x: 4.5, y: 15.8),
            controlPoint1: NSPoint(x: 2.4, y: 14.9),
            controlPoint2: NSPoint(x: 3.3, y: 15.8)
        )
        outline.line(to: NSPoint(x: 8.9, y: 15.8))

        // A small display notch keeps the silhouette recognizably modern.
        outline.curve(
            to: NSPoint(x: 9.8, y: 14.9),
            controlPoint1: NSPoint(x: 9.4, y: 15.8),
            controlPoint2: NSPoint(x: 9.8, y: 15.4)
        )
        outline.line(to: NSPoint(x: 12.2, y: 14.9))
        outline.curve(
            to: NSPoint(x: 13.1, y: 15.8),
            controlPoint1: NSPoint(x: 12.7, y: 14.9),
            controlPoint2: NSPoint(x: 13.1, y: 15.4)
        )

        outline.line(to: NSPoint(x: 17.5, y: 15.8))
        outline.curve(
            to: NSPoint(x: 19.6, y: 13.7),
            controlPoint1: NSPoint(x: 18.7, y: 15.8),
            controlPoint2: NSPoint(x: 19.6, y: 14.9)
        )
        outline.line(to: NSPoint(x: 19.6, y: 5.1))
        outline.close()
        outline.lineWidth = 1.35
        outline.lineCapStyle = .round
        outline.lineJoinStyle = .round
        NSColor.black.setStroke()
        outline.stroke()
    }

    private static func drawBase() {
        let base = NSBezierPath()
        base.move(to: NSPoint(x: 0.8, y: 3.9))
        base.line(to: NSPoint(x: 8.2, y: 3.9))
        base.curve(
            to: NSPoint(x: 9.3, y: 3.25),
            controlPoint1: NSPoint(x: 8.6, y: 3.9),
            controlPoint2: NSPoint(x: 8.7, y: 3.25)
        )
        base.line(to: NSPoint(x: 12.7, y: 3.25))
        base.curve(
            to: NSPoint(x: 13.8, y: 3.9),
            controlPoint1: NSPoint(x: 13.3, y: 3.25),
            controlPoint2: NSPoint(x: 13.4, y: 3.9)
        )
        base.line(to: NSPoint(x: 21.2, y: 3.9))
        base.curve(
            to: NSPoint(x: 19.8, y: 2.25),
            controlPoint1: NSPoint(x: 21.0, y: 3.0),
            controlPoint2: NSPoint(x: 20.5, y: 2.25)
        )
        base.line(to: NSPoint(x: 2.2, y: 2.25))
        base.curve(
            to: NSPoint(x: 0.8, y: 3.9),
            controlPoint1: NSPoint(x: 1.5, y: 2.25),
            controlPoint2: NSPoint(x: 1.0, y: 3.0)
        )
        base.close()
        NSColor.black.setFill()
        base.fill()
    }

    private static func drawMendingMark() {
        let seam = NSBezierPath()
        seam.move(to: NSPoint(x: 15.25, y: 14.55))
        seam.line(to: NSPoint(x: 18.25, y: 9.65))
        seam.lineWidth = 0.85
        seam.lineCapStyle = .round
        NSColor.black.setStroke()
        seam.stroke()

        let stitches = NSBezierPath()
        stitches.move(to: NSPoint(x: 14.75, y: 13.25))
        stitches.line(to: NSPoint(x: 16.45, y: 14.3))
        stitches.move(to: NSPoint(x: 15.75, y: 11.65))
        stitches.line(to: NSPoint(x: 17.45, y: 12.7))
        stitches.move(to: NSPoint(x: 16.75, y: 10.05))
        stitches.line(to: NSPoint(x: 18.4, y: 11.05))
        stitches.lineWidth = 1.05
        stitches.lineCapStyle = .round
        stitches.stroke()
    }
}
