import AppKit
import SwiftUI

@MainActor
protocol MenuBarSecondaryBarControllerDelegate: AnyObject {
    func menuBarSecondaryBarControllerDidRequestRevealInMenuBar(_ controller: MenuBarSecondaryBarController)
    func menuBarSecondaryBarController(_ controller: MenuBarSecondaryBarController, didRequestSection section: MenuBarSection, for item: DetectedMenuBarItem)
}

@MainActor
final class MenuBarSecondaryBarController {
    private var panel: NSPanel?
    weak var delegate: MenuBarSecondaryBarControllerDelegate?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func containsMouseLocation(_ location: CGPoint) -> Bool {
        panel?.frame.insetBy(dx: -8, dy: -8).contains(location) == true
    }

    func show(items: [DetectedMenuBarItem], anchorScreen: NSScreen? = NSScreen.main) {
        guard !items.isEmpty else {
            hide()
            return
        }

        let content = MenuBarSecondaryBarView(
            items: items,
            revealInMenuBar: { [weak self] in
                guard let self else { return }
                self.delegate?.menuBarSecondaryBarControllerDidRequestRevealInMenuBar(self)
            },
            setSection: { [weak self] item, section in
                guard let self else { return }
                self.delegate?.menuBarSecondaryBarController(self, didRequestSection: section, for: item)
            }
        )

        let hosting = NSHostingView(rootView: content)
        let targetPanel = panel ?? makePanel()
        targetPanel.contentView = hosting
        targetPanel.setFrame(frame(forItemCount: items.count, on: anchorScreen), display: true)
        targetPanel.orderFrontRegardless()
        panel = targetPanel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        return panel
    }

    private func frame(forItemCount itemCount: Int, on screen: NSScreen?) -> CGRect {
        let screenFrame = screen?.frame ?? NSScreen.main?.frame ?? .zero
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? screenFrame
        let width = min(max(CGFloat(itemCount) * 118 + 168, 420), min(visibleFrame.width - 32, 940))
        let height: CGFloat = 96
        let x = visibleFrame.midX - width / 2
        let menuBarHeight = max(24, screenFrame.height - visibleFrame.height)
        let y = screenFrame.maxY - menuBarHeight - height - 8
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct MenuBarSecondaryBarView: View {
    var items: [DetectedMenuBarItem]
    var revealInMenuBar: () -> Void
    var setSection: (DetectedMenuBarItem, MenuBarSection) -> Void

    var body: some View {
        HStack(spacing: 10) {
            MendyAvatarView(mood: .thinking, size: MendyAvatarSize.compact)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        MenuBarSecondaryItemButton(item: item) {
                            setSection(item, .pinned)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Button {
                revealInMenuBar()
            } label: {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .help("Reveal in the menu bar")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .padding(1)
    }
}

private struct MenuBarSecondaryItemButton: View {
    var item: DetectedMenuBarItem
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .overlay {
                        Text(String(item.displayTitle.prefix(1)).uppercased())
                            .font(.caption.weight(.bold))
                    }
                    .frame(width: 26, height: 26)
                Text(item.displayTitle)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Move \(item.displayTitle) back to Visible")
    }
}
