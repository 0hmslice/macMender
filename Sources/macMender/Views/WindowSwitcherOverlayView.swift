import AppKit
import SwiftUI

struct WindowSwitcherOverlayView: View {
    @ObservedObject var service: WindowSwitcherService
    var settings: WindowSwitcherSettings

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(service.displayThumbnailSize + 22), spacing: 12), count: max(service.gridColumnCount, 1))
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                content
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if settings.layout == .strip {
            stripContent
        } else {
            gridContent
        }
    }

    private var gridContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(service.overlayTitle, systemImage: service.isDockPreview ? "dock.arrow.up.rectangle" : "rectangle.3.group")
                    .font(.headline)
                Spacer()
                Text(service.overlaySubtitle.isEmpty ? "\(service.windows.count) windows" : service.overlaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                cards
            }
            .padding(2)
        }
        .padding(18)
        .macMenderGlassSurface(radius: MacMenderRadius.prominent)
    }

    private var stripContent: some View {
        WindowSwitcherStrip(service: service)
            .padding(14)
            .macMenderGlassSurface(radius: MacMenderRadius.prominent)
    }

    private var cards: some View {
        ForEach(Array(service.windows.enumerated()), id: \.element.id) { index, window in
            WindowSwitcherCard(
                window: window,
                image: service.thumbnail(for: window, size: CGSize(width: service.displayThumbnailSize, height: service.displayThumbnailSize * 0.68)),
                isSelected: index == service.selectedIndex,
                thumbnailSize: service.displayThumbnailSize,
                select: { service.select(index: index, source: .mouseHover) },
                activate: {
                    service.select(index: index, source: .mouseClick)
                    service.activateDisplayedWindow(window, displayedIndex: index, source: .mouseClick)
                },
                minimize: { service.minimize(window) },
                close: { service.close(window) }
            )
        }
    }
}

private struct WindowSwitcherCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityShowBorders) private var showBorders
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var window: WindowSummary
    var image: NSImage?
    var isSelected: Bool
    var thumbnailSize: Double
    var select: () -> Void
    var activate: () -> Void
    var minimize: () -> Void
    var close: () -> Void

    var body: some View {
        Button(action: activate) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .underPageBackgroundColor))

                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 8))
                            .padding(4)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "macwindow")
                                .font(.system(size: 34))
                            Text("Thumbnail unavailable")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                }
                .frame(width: thumbnailSize, height: thumbnailSize * 0.68)
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(strongBorder ? 0.9 : 0.45), lineWidth: strongBorder ? 1.5 : 1)
                }

                HStack(alignment: .center, spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: NSRunningApplication(processIdentifier: window.processIdentifier)?.bundleURL?.path ?? ""))
                        .resizable()
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(window.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(window.appName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(10)
            .frame(width: thumbnailSize + 22, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: cardBorderWidth)
            }
            .animation(MacMenderMotion.feedback(reduceMotion: reduceMotion), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering in
            if hovering {
                select()
            }
        }
        .contextMenu {
            Button("Activate", action: activate)
            Button("Minimize", action: minimize)
            Button("Close", role: .destructive, action: close)
        }
    }

    private var strongBorder: Bool {
        colorSchemeContrast == .increased || showBorders
    }

    private var cardBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(strongBorder ? 0.20 : 0.12)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var cardBorder: Color {
        isSelected
            ? Color.accentColor
            : Color(nsColor: .separatorColor).opacity(strongBorder ? 1 : 0.6)
    }

    private var cardBorderWidth: CGFloat {
        if isSelected {
            return strongBorder ? 3 : 2
        }
        return strongBorder ? 1.5 : 1
    }

    private var accessibilityLabel: String {
        var parts = [window.title, window.appName]
        if window.isMinimized {
            parts.append("Minimized")
        }
        if isSelected {
            parts.append("Selected")
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityHint: String {
        if isSelected {
            return "Activates the selected window. Use the context menu to minimize or close it."
        }
        return "Selects and activates this window. Use the context menu to minimize or close it."
    }
}

private struct WindowSwitcherStrip: View {
    @ObservedObject var service: WindowSwitcherService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 11) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(service.windows.enumerated()), id: \.element.id) { index, window in
                            WindowSwitcherStripCard(
                                window: window,
                                image: service.thumbnail(
                                    for: window,
                                    size: CGSize(
                                        width: service.displayThumbnailSize,
                                        height: service.displayThumbnailSize * 0.68
                                    )
                                ),
                                isSelected: index == service.selectedIndex,
                                thumbnailSize: service.displayThumbnailSize,
                                select: { service.select(index: index, source: .mouseHover) },
                                activate: {
                                    service.select(index: index, source: .mouseClick)
                                    service.activateDisplayedWindow(window, displayedIndex: index, source: .mouseClick)
                                },
                                minimize: { service.minimize(window) },
                                close: { service.close(window) }
                            )
                            .id(window.id)
                        }
                    }
                    .padding(4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: service.selectedIndex) {
                    guard service.windows.indices.contains(service.selectedIndex) else { return }
                    let selectedID = service.windows[service.selectedIndex].id
                    if reduceMotion {
                        proxy.scrollTo(selectedID, anchor: .center)
                    } else {
                        withAnimation(.easeOut(duration: 0.14)) {
                            proxy.scrollTo(selectedID, anchor: .center)
                        }
                    }
                }
            }

            if let selectedWindow = service.selectedWindow {
                VStack(spacing: 2) {
                    Text(selectedWindow.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(selectedWindow.appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Selected window, \(selectedWindow.title), \(selectedWindow.appName)")
            }
        }
    }
}

private struct WindowSwitcherStripCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityShowBorders) private var showBorders
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var window: WindowSummary
    var image: NSImage?
    var isSelected: Bool
    var thumbnailSize: Double
    var select: () -> Void
    var activate: () -> Void
    var minimize: () -> Void
    var close: () -> Void

    var body: some View {
        Button(action: activate) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .underPageBackgroundColor))

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 8))
                        .padding(5)
                } else {
                    VStack(spacing: 7) {
                        Image(nsImage: applicationIcon)
                            .resizable()
                            .frame(width: 38, height: 38)
                        Text("Preview unavailable")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(width: thumbnailSize, height: thumbnailSize * 0.68)
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .padding(4)
            .background(
                isSelected ? Color.accentColor.opacity(strongBorder ? 0.20 : 0.13) : .clear,
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .animation(MacMenderMotion.feedback(reduceMotion: reduceMotion), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Activate this window. Use the context menu to minimize or close it.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering in
            if hovering {
                select()
            }
        }
        .contextMenu {
            Button("Activate", action: activate)
            Button("Minimize", action: minimize)
            Button("Close", role: .destructive, action: close)
        }
    }

    private var applicationIcon: NSImage {
        guard let path = NSRunningApplication(
            processIdentifier: window.processIdentifier
        )?.bundleURL?.path else {
            return NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    private var strongBorder: Bool {
        colorSchemeContrast == .increased || showBorders
    }

    private var borderColor: Color {
        isSelected ? .accentColor : Color(nsColor: .separatorColor).opacity(strongBorder ? 1 : 0.65)
    }

    private var borderWidth: CGFloat {
        if isSelected {
            return strongBorder ? 4 : 3
        }
        return strongBorder ? 1.5 : 1
    }

    private var accessibilityLabel: String {
        var parts = [window.title, window.appName]
        if window.isMinimized {
            parts.append("Minimized")
        }
        if isSelected {
            parts.append("Selected")
        }
        return parts.joined(separator: ", ")
    }
}
