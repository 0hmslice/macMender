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

    private var content: some View {
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
        .liquidGlass(.preview)
        .overlay {
            RoundedRectangle(cornerRadius: LiquidGlassSurface.preview.radius, style: .continuous)
                .stroke(Color.accentColor.opacity(service.isDockPreview ? 0.18 : 0.12), lineWidth: 1)
        }
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
                    service.commit(source: .mouseClick)
                },
                minimize: { service.minimize(window) },
                close: { service.close(window) }
            )
        }
    }
}

private struct WindowSwitcherCard: View {
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
                        .fill(.black.opacity(0.12))

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
                .liquidGlass(.preview)

                HStack(alignment: .center, spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: NSRunningApplication(processIdentifier: window.processIdentifier)?.bundleURL?.path ?? ""))
                        .resizable()
                        .frame(width: 22, height: 22)
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
            .liquidGlass(.row)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: Color.accentColor.opacity(isSelected ? 0.18 : 0), radius: 12, y: 5)
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(LiquidGlassMotion.quick, value: isSelected)
        }
        .buttonStyle(.plain)
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
}
