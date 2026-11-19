import AppKit
import SwiftUI

/// The floating preview shown beside the Dock: one card per window of the hovered application.
struct DockPreviewView: View {
    @ObservedObject var controller: DockPreviewController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let presentation = controller.presentation {
                DockPreviewContent(controller: controller, presentation: presentation)
                    .id(controller.contentGeneration)
                    .transition(.opacity)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : hiddenScale, anchor: scaleAnchor(for: presentation.edge))
                    .offset(isVisible ? .zero : hiddenOffset(for: presentation.edge))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(phaseAnimation, value: controller.phase)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: controller.contentGeneration)
    }

    private var isVisible: Bool {
        controller.phase == .visible
    }

    private var style: DockPreviewAnimationStyle {
        let style = controller.settings.animationStyle.legacyMappedStyle
        return reduceMotion && style != .none ? .fade : style
    }

    private var phaseAnimation: Animation? {
        guard style != .none else { return nil }
        return isVisible
            ? .timingCurve(0.2, 0.8, 0.2, 1, duration: controller.appearAnimationDuration)
            : .easeIn(duration: controller.dismissAnimationDuration)
    }

    private var hiddenScale: CGFloat {
        switch style {
        case .system: 0.96
        case .scale: 0.82
        default: 1
        }
    }

    /// Previews grow out of the Dock edge they belong to.
    private func scaleAnchor(for edge: DockEdge) -> UnitPoint {
        switch edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    private func hiddenOffset(for edge: DockEdge) -> CGSize {
        let distance: CGFloat
        switch style {
        case .system: distance = 10
        case .slideUp: distance = 24
        default: return .zero
        }
        switch edge {
        case .bottom: return CGSize(width: 0, height: distance)
        case .left: return CGSize(width: -distance, height: 0)
        case .right: return CGSize(width: distance, height: 0)
        }
    }
}

private struct DockPreviewContent: View {
    @ObservedObject var controller: DockPreviewController
    var presentation: DockPreviewController.Presentation

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityShowBorders) private var showBorders
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private static let cornerRadius: CGFloat = 18

    var body: some View {
        let layout = presentation.layout
        let applicationIcon = controller.applicationIcon(for: presentation)

        ZStack(alignment: .topLeading) {
            ForEach(Array(presentation.windows.prefix(layout.cardFrames.count).enumerated()), id: \.element.id) { index, window in
                let frame = layout.cardFrames[index]
                DockPreviewCard(
                    controller: controller,
                    window: window,
                    image: controller.thumbnails[window.id],
                    applicationIcon: applicationIcon,
                    thumbnailSize: layout.thumbnailSizes[index],
                    isHovered: controller.hoveredWindowID == window.id
                )
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
            }

            if layout.hiddenCount > 0 {
                Text("+\(layout.hiddenCount) more \(layout.hiddenCount == 1 ? "window" : "windows")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: layout.contentSize.width, height: DockPreviewLayout.Metrics.footerHeight)
                    .offset(y: layout.contentSize.height - DockPreviewLayout.Metrics.footerHeight - 4)
            }
        }
        .frame(width: layout.contentSize.width, height: layout.contentSize.height, alignment: .topLeading)
        .modifier(DockPreviewSurface(cornerRadius: Self.cornerRadius, reduceTransparency: reduceTransparency, strongBorder: strongBorder))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(presentation.appName) windows")
    }

    private var strongBorder: Bool {
        colorSchemeContrast == .increased || showBorders
    }
}

private struct DockPreviewSurface: ViewModifier {
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

private struct DockPreviewCard: View {
    @ObservedObject var controller: DockPreviewController
    var window: WindowSummary
    var image: CGImage?
    var applicationIcon: NSImage?
    var thumbnailSize: CGSize
    var isHovered: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    private static let thumbnailRadius: CGFloat = 7

    var body: some View {
        Button {
            controller.activate(window)
        } label: {
            VStack(spacing: 0) {
                thumbnail
                if controller.settings.showTitles {
                    Text(window.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary.opacity(isHovered ? 1 : 0.82))
                        .frame(width: thumbnailSize.width - 4, height: DockPreviewLayout.Metrics.titleHeight)
                }
            }
            .padding(DockPreviewLayout.Metrics.cardPadding)
            .background(
                Color.primary.opacity(isHovered ? 0.12 : 0),
                in: RoundedRectangle(cornerRadius: Self.thumbnailRadius + 4, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if isHovered, controller.settings.showWindowControls {
                controls
                    .padding(DockPreviewLayout.Metrics.cardPadding + 5)
                    .transition(.opacity)
            }
        }
        .animation(MacMenderMotion.feedback(reduceMotion: reduceMotion), value: isHovered)
        .onHover { hovering in
            if hovering {
                controller.hoveredWindowID = window.id
            } else if controller.hoveredWindowID == window.id {
                controller.hoveredWindowID = nil
            }
        }
        .contextMenu { menu }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Brings this window to the front.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Close") { controller.close(window) }
        .accessibilityAction(named: window.isMinimized ? "Restore" : "Minimize") { controller.toggleMinimized(window) }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.thumbnailRadius, style: .continuous)
                .fill(Color.primary.opacity(0.06))

            if let image {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: 6) {
                    if let applicationIcon {
                        Image(nsImage: applicationIcon)
                            .resizable()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "macwindow")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .clipShape(.rect(cornerRadius: Self.thumbnailRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.thumbnailRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            if let badge = statusBadge {
                Image(systemName: badge.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 20, height: 20)
                    .background(.regularMaterial, in: Circle())
                    .padding(5)
                    .help(badge.label)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 6) {
            DockPreviewControlButton(color: Color(red: 1.0, green: 0.37, blue: 0.34), symbol: "xmark", label: "Close") {
                controller.close(window)
            }
            DockPreviewControlButton(
                color: Color(red: 1.0, green: 0.74, blue: 0.18),
                symbol: window.isMinimized ? "arrow.up" : "minus",
                label: window.isMinimized ? "Restore" : "Minimize"
            ) {
                controller.toggleMinimized(window)
            }
            DockPreviewControlButton(
                color: Color(red: 0.16, green: 0.78, blue: 0.25),
                symbol: window.isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                label: window.isFullScreen ? "Exit Full Screen" : "Enter Full Screen"
            ) {
                controller.toggleFullScreen(window)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }

    @ViewBuilder
    private var menu: some View {
        Button("Bring to Front") { controller.activate(window) }
        Button(window.isMinimized ? "Restore" : "Minimize") { controller.toggleMinimized(window) }
        Button(window.isFullScreen ? "Exit Full Screen" : "Enter Full Screen") { controller.toggleFullScreen(window) }
        Button("Close Window") { controller.close(window) }
        Divider()
        Button("Close All Windows") { controller.closeAllWindows() }
        Button("Hide \(window.appName)") { controller.hideApplication() }
        Button("Quit \(window.appName)") { controller.quitApplication() }
    }

    private var statusBadge: (symbol: String, label: String)? {
        if window.isMinimized { return ("minus", "Minimized") }
        if window.isAppHidden { return ("eye.slash", "Hidden") }
        if window.isFullScreen { return ("arrow.up.left.and.arrow.down.right", "Full screen") }
        if window.isOnOtherSpace { return ("rectangle.on.rectangle", "On another Space") }
        return nil
    }

    private var accessibilityLabel: String {
        var parts = [window.title]
        if let badge = statusBadge {
            parts.append(badge.label)
        }
        return parts.joined(separator: ", ")
    }
}

private struct DockPreviewControlButton: View {
    var color: Color
    var symbol: String
    var label: String
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 7.5, weight: .heavy))
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
