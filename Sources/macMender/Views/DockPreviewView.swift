import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
            if layout.headerHeight > 0 {
                DockPreviewHeader(controller: controller, presentation: presentation, applicationIcon: applicationIcon)
                    .frame(width: layout.contentSize.width, height: layout.headerHeight)
            }

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
        .modifier(GlassPanelSurface(cornerRadius: Self.cornerRadius, reduceTransparency: reduceTransparency, strongBorder: strongBorder))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(presentation.appName) windows")
    }

    private var strongBorder: Bool {
        colorSchemeContrast == .increased || showBorders
    }
}

/// Names the application whose windows are on show and offers Hide and Quit.
private struct DockPreviewHeader: View {
    @ObservedObject var controller: DockPreviewController
    var presentation: DockPreviewController.Presentation
    var applicationIcon: NSImage?

    var body: some View {
        let name = presentation.windows.first?.appName ?? presentation.appName
        HStack(spacing: 7) {
            if let applicationIcon {
                Image(nsImage: applicationIcon)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            }
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            if presentation.windows.count > 1 {
                Text("\(presentation.windows.count)")
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                    .accessibilityLabel("\(presentation.windows.count) windows")
            }
            Spacer(minLength: 8)
            DockPreviewHeaderButton(symbol: "eye.slash", label: "Hide \(name)") {
                controller.hideApplication()
            }
            DockPreviewHeaderButton(symbol: "power", label: "Quit \(name)") {
                controller.quitApplication()
            }
        }
        .padding(.leading, DockPreviewLayout.Metrics.contentPadding + 6)
        .padding(.trailing, DockPreviewLayout.Metrics.contentPadding + 2)
        .padding(.top, 4)
    }
}

private struct DockPreviewHeaderButton: View {
    var symbol: String
    var label: String
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(isHovered ? 0.95 : 0.6))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(isHovered ? 0.12 : 0), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
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
    @State private var isDropTargeted = false

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
        // Resting a dragged file on a card brings its window forward so the file can be dropped there.
        .onDrop(of: [UTType.item], isTargeted: $isDropTargeted) { _ in false }
        .onChange(of: isDropTargeted) { _, targeted in
            controller.dragTargetChanged(window, isTargeted: targeted)
        }
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
        HStack(spacing: 5) {
            WindowControlButton(color: WindowControlButton.closeColor, symbol: "xmark", label: "Close") {
                controller.close(window)
            }
            WindowControlButton(
                color: WindowControlButton.minimizeColor,
                symbol: window.isMinimized ? "arrow.up" : "minus",
                label: window.isMinimized ? "Restore" : "Minimize"
            ) {
                controller.toggleMinimized(window)
            }
            WindowControlButton(
                color: WindowControlButton.fullScreenColor,
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

    private var statusBadge: (symbol: String, label: String)? { window.statusBadge }

    private var accessibilityLabel: String {
        var parts = [window.title]
        if let badge = statusBadge {
            parts.append(badge.label)
        }
        return parts.joined(separator: ", ")
    }
}
