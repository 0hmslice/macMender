import AppKit
import Combine
import SwiftUI

@MainActor
final class MacMenderStatusItemController: NSObject {
    private static let statusItemAutosaveName = "macMender.StatusItem"
    private static let statusItemImageSize = NSSize(width: 22, height: 18)
    private static let minimumStatusItemLength: CGFloat = 24
    private static let maximumStatusItemLength: CGFloat = 42

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var appModel: AppModel?
    private var openPreferences: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()

    func install(appModel: AppModel, openPreferences: @escaping () -> Void) {
        let shouldRebind = self.appModel !== appModel
        self.appModel = appModel
        self.openPreferences = openPreferences

        if statusItem == nil {
            migrateLegacyHardLeftPositionIfNeeded(autosaveName: Self.statusItemAutosaveName)
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.autosaveName = Self.statusItemAutosaveName
            item.button?.target = self
            item.button?.action = #selector(togglePopover)
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            item.button?.toolTip = "macMender"
            statusItem = item
        }

        updateIcon()
        updateStatusItemLength()
        if shouldRebind {
            bindSpacingUpdates(from: appModel)
        }
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
        image.size = Self.statusItemImageSize
        button.image = image
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel("macMender")
    }

    private func updateStatusItemLength() {
        guard let statusItem else { return }
        guard let spacingValue = effectiveSpacingValue() else {
            statusItem.length = NSStatusItem.variableLength
            return
        }
        let horizontalPadding = CGFloat(MenuBarSpacingPreference.clampedValue(spacingValue))
        let length = Self.statusItemImageSize.width + horizontalPadding
        statusItem.length = min(Self.maximumStatusItemLength, max(Self.minimumStatusItemLength, length))
    }

    private func effectiveSpacingValue() -> Int? {
        guard let appModel else { return nil }
        let behavior = appModel.store.config.appBehavior
        if let configuredValue = behavior.menuBarSpacing.resolvedDefaultsValue(customValue: behavior.menuBarSpacingCustomValue) {
            return configuredValue
        }
        return MenuBarSpacingService.currentDefaultsValues().sharedValue
    }

    private func bindSpacingUpdates(from appModel: AppModel) {
        cancellables.removeAll()

        appModel.store.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemLength()
            }
            .store(in: &cancellables)

        appModel.menuBarSpacing.$currentValues
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemLength()
            }
            .store(in: &cancellables)
    }

    private func rebuildPopover() {
        guard let appModel else { return }
        let popover = popover ?? NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 292, height: 236)
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
