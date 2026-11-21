import AppKit
import SwiftUI

/// The keyboard window switcher: every window as a card on a glass panel, in the same style as
/// Dock previews.
struct WindowSwitcherOverlayView: View {
    @ObservedObject var service: WindowSwitcherService
    var settings: WindowSwitcherSettings
    /// The widest the panel may be; a strip scrolls sideways beyond it.
    var maximumWidth: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityShowBorders) private var showBorders
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private static let cardSpacing: CGFloat = 6
    private static let padding: CGFloat = 12

    var body: some View {
        VStack(spacing: 8) {
            if settings.layout == .strip {
                strip
            } else {
                grid
            }
            footer
        }
        .padding(Self.padding)
        .modifier(GlassPanelSurface(
            cornerRadius: 18,
            reduceTransparency: reduceTransparency,
            strongBorder: colorSchemeContrast == .increased || showBorders
        ))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Window switcher")
    }

    private var grid: some View {
        let columns = max(service.gridColumnCount, 1)
        let indexed = Array(service.windows.enumerated())
        let rows = stride(from: 0, to: indexed.count, by: columns).map { Array(indexed[$0..<min($0 + columns, indexed.count)]) }

        return VStack(spacing: Self.cardSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Self.cardSpacing) {
                    ForEach(row, id: \.element.id) { index, window in
                        card(window, at: index)
                    }
                }
            }
        }
    }

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Self.cardSpacing) {
                    ForEach(Array(service.windows.enumerated()), id: \.element.id) { index, window in
                        card(window, at: index)
                            .id(window.id)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: maximumWidth - Self.padding * 2)
            .onChange(of: service.selectedIndex) {
                guard let selected = service.selectedWindow else { return }
                proxy.scrollTo(selected.id, anchor: .center)
            }
        }
    }

    private func card(_ window: WindowSummary, at index: Int) -> some View {
        WindowSwitcherCard(
            window: window,
            image: service.thumbnail(for: window, size: .zero),
            isSelected: index == service.selectedIndex,
            thumbnailWidth: service.displayThumbnailSize,
            select: { service.select(index: index, source: .mouseHover) },
            activate: {
                service.select(index: index, source: .mouseClick)
                service.activateDisplayedWindow(window, displayedIndex: index, source: .mouseClick)
            },
            minimize: { service.minimize(window) },
            close: { service.close(window) }
        )
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .fixedSize()
    }

    /// The selected window's name, and the keys that work while the switcher is open.
    private var footer: some View {
        HStack(spacing: 10) {
            if let selected = service.selectedWindow {
                Text(selected.appName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .layoutPriority(2)
                Text(selected.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
            }
            Spacer(minLength: 12)
            // The hints give way before the window's name does.
            ViewThatFits(in: .horizontal) {
                hint("←  →  move   ·   W  close   ·   M  minimize   ·   esc  cancel")
                hint("W  close   ·   M  minimize")
                EmptyView()
            }
            .accessibilityLabel("Arrow keys move, W closes, M minimizes, Escape cancels")
        }
        .padding(.horizontal, 6)
        .frame(minWidth: 420)
    }
}

private struct WindowSwitcherCard: View {
    var window: WindowSummary
    var image: NSImage?
    var isSelected: Bool
    var thumbnailWidth: Double
    var select: () -> Void
    var activate: () -> Void
    var minimize: () -> Void
    var close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private static let thumbnailRadius: CGFloat = 7
    private var thumbnailSize: CGSize { CGSize(width: thumbnailWidth, height: thumbnailWidth * 0.68) }

    var body: some View {
        Button(action: activate) {
            VStack(spacing: 5) {
                thumbnail
                HStack(spacing: 5) {
                    Image(nsImage: applicationIcon)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                    Text(window.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary.opacity(isSelected ? 1 : 0.82))
                }
                .frame(width: thumbnailSize.width - 4)
            }
            .padding(6)
            .background(
                Color.primary.opacity(isSelected ? 0.14 : 0),
                in: RoundedRectangle(cornerRadius: Self.thumbnailRadius + 4, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Self.thumbnailRadius + 4, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(isSelected ? 1 : 0), lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if isSelected || isHovered {
                controls
                    .padding(11)
                    .transition(.opacity)
            }
        }
        .animation(MacMenderMotion.feedback(reduceMotion: reduceMotion), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
            if hovering { select() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Switches to this window.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { activate() }
        .accessibilityAction(named: "Close") { close() }
        .accessibilityAction(named: "Minimize") { minimize() }
    }

    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: Self.thumbnailRadius, style: .continuous)
        return Group {
            if let image {
                // The outline follows the window's own shape, whatever its proportions.
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(shape)
                    .overlay { shape.strokeBorder(Color.primary.opacity(0.14), lineWidth: 1) }
                    .overlay(alignment: .bottomTrailing) { badge }
            } else {
                shape
                    .fill(Color.primary.opacity(0.06))
                    .overlay {
                        Image(nsImage: applicationIcon)
                            .resizable()
                            .frame(width: 44, height: 44)
                    }
                    .overlay(alignment: .bottomTrailing) { badge }
            }
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
    }

    @ViewBuilder
    private var badge: some View {
        if let badge = window.statusBadge {
            Image(systemName: badge.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 20, height: 20)
                .background(.regularMaterial, in: Circle())
                .padding(5)
                .help(badge.label)
        }
    }

    private var controls: some View {
        HStack(spacing: 5) {
            WindowControlButton(color: WindowControlButton.closeColor, symbol: "xmark", label: "Close", action: close)
            WindowControlButton(color: WindowControlButton.minimizeColor, symbol: "minus", label: "Minimize", action: minimize)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }

    private var applicationIcon: NSImage {
        NSRunningApplication(processIdentifier: window.processIdentifier)?.icon
            ?? NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
            ?? NSImage()
    }

    private var accessibilityLabel: String {
        var parts = [window.title, window.appName]
        if let badge = window.statusBadge { parts.append(badge.label) }
        if isSelected { parts.append("Selected") }
        return parts.joined(separator: ", ")
    }
}
