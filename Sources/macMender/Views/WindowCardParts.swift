import AppKit
import SwiftUI

/// The floating glass panel behind window cards, shared by Dock previews and the window switcher.
struct GlassPanelSurface: ViewModifier {
    var cornerRadius: CGFloat
    var reduceTransparency: Bool
    var strongBorder: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay { border(shape) }
                .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
        } else if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay { if strongBorder { border(shape) } }
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay { border(shape) }
                .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
        }
    }

    private func border(_ shape: RoundedRectangle) -> some View {
        shape
            .strokeBorder(Color(nsColor: .separatorColor).opacity(strongBorder ? 1 : 0.5), lineWidth: strongBorder ? 1.5 : 1)
            .allowsHitTesting(false)
    }
}

/// One of the coloured window buttons shown on a card: close, minimize, or full screen.
struct WindowControlButton: View {
    var color: Color
    var symbol: String
    var label: String
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 8.5, weight: .heavy))
                        .foregroundStyle(.black.opacity(isHovered ? 0.75 : 0.5))
                }
                .overlay {
                    Circle().strokeBorder(.black.opacity(0.18), lineWidth: 0.5)
                }
                .scaleEffect(isHovered ? 1.12 : 1)
                // A larger target than the visible dot.
                .padding(2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

extension WindowControlButton {
    static let closeColor = Color(red: 1.0, green: 0.37, blue: 0.34)
    static let minimizeColor = Color(red: 1.0, green: 0.74, blue: 0.18)
    static let fullScreenColor = Color(red: 0.16, green: 0.78, blue: 0.25)
}

extension WindowSummary {
    /// A small symbol and description for a window that is not simply on screen.
    var statusBadge: (symbol: String, label: String)? {
        if isMinimized { return ("minus", "Minimized") }
        if isAppHidden { return ("eye.slash", "Hidden") }
        if isFullScreen { return ("arrow.up.left.and.arrow.down.right", "Full screen") }
        if isOnOtherSpace { return ("rectangle.on.rectangle", "On another Space") }
        return nil
    }
}
