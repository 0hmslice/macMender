import AppKit
import SwiftUI

private struct MacMenderGlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityShowBorders) private var showBorders
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var radius: CGFloat
    var interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            fallback(content)
        } else if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(interactive), in: .rect(cornerRadius: radius))
                .overlay { border }
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay { border }
        }
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay { border }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                Color(nsColor: .separatorColor)
                    .opacity(strongBorder ? 1 : 0.45),
                lineWidth: strongBorder ? 1.5 : 1
            )
            .allowsHitTesting(false)
    }

    private var strongBorder: Bool {
        colorSchemeContrast == .increased || showBorders
    }
}

extension View {
    func macMenderGlassSurface(
        radius: CGFloat = MacMenderRadius.content,
        interactive: Bool = false
    ) -> some View {
        modifier(MacMenderGlassSurfaceModifier(radius: radius, interactive: interactive))
    }
}
