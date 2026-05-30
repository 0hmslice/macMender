import AppKit
import SwiftUI

@MainActor
final class MacMenderStatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var appModel: AppModel?
    private var openPreferences: (() -> Void)?

    func install(appModel: AppModel, openPreferences: @escaping () -> Void) {
        self.appModel = appModel
        self.openPreferences = openPreferences

        if statusItem == nil {
            migrateLegacyHardLeftPositionIfNeeded(autosaveName: MenuBarControlIdentifier.visible)
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.autosaveName = MenuBarControlIdentifier.visible
            item.button?.target = self
            item.button?.action = #selector(togglePopover)
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            item.button?.toolTip = "macMender"
            statusItem = item
        }

        updateIcon()
        rebuildPopover()
    }

    func frameInScreen() -> CGRect? {
        statusItem?.button?.window?.frame
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            rebuildPopover()
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let image = MendyAssets.menuBarImage.copy() as? NSImage ?? MendyAssets.menuBarImage
        image.isTemplate = true
        image.size = NSSize(width: 22, height: 18)
        button.image = image
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel("macMender")
    }

    private func rebuildPopover() {
        guard let appModel else { return }
        let popover = popover ?? NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 300, height: 190)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopover(
                appModel: appModel,
                openSettingsAction: { [weak self] in self?.openPreferences?() },
                closeAction: { [weak self] in self?.popover?.performClose(nil) }
            )
        )
        self.popover = popover
    }

    private func migrateLegacyHardLeftPositionIfNeeded(autosaveName: String) {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        let migrationKey = "\(key) MigratedFromHardLeft"
        guard !UserDefaults.standard.bool(forKey: migrationKey),
              let position = UserDefaults.standard.object(forKey: key) as? Double,
              position <= 1 else {
            return
        }
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
