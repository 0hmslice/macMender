import AppKit

@MainActor
protocol MenuBarControlItemControllerDelegate: AnyObject {
    func menuBarControlItemControllerDidToggleHiddenSection(_ controller: MenuBarControlItemController)
    func menuBarControlItemControllerDidToggleAlwaysHiddenSection(_ controller: MenuBarControlItemController)
}

@MainActor
final class MenuBarControlItemController: NSObject {
    private enum Length {
        static let standard: CGFloat = NSStatusItem.variableLength
        static let expanded: CGFloat = 10_000
        static let divider: CGFloat = 7
    }

    private var hiddenControl: NSStatusItem?
    private var alwaysHiddenControl: NSStatusItem?
    private var hiddenConstraint: NSLayoutConstraint?
    private var alwaysHiddenConstraint: NSLayoutConstraint?
    private var spacerItems: [NSStatusItem] = []
    private var layout = MenuBarLayout.default

    weak var delegate: MenuBarControlItemControllerDelegate?
    private(set) var controlsInstalled = false

    func installIfNeeded(layout: MenuBarLayout) {
        self.layout = layout
        guard hiddenControl == nil else {
            controlsInstalled = true
            return
        }

        setPreferredPosition(10_000, autosaveName: MenuBarControlIdentifier.hidden)
        clearPreferredPosition(autosaveName: MenuBarControlIdentifier.alwaysHidden)

        let hidden = NSStatusBar.system.statusItem(withLength: 0)
        hidden.autosaveName = MenuBarControlIdentifier.hidden
        hidden.button?.target = self
        hidden.button?.action = #selector(toggleHiddenFromStatusItem)
        hidden.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        hidden.button?.toolTip = "macMender Hidden divider"
        hiddenConstraint = Self.controlItemConstraint(for: hidden.button)
        hiddenControl = hidden

        let alwaysHidden = NSStatusBar.system.statusItem(withLength: 0)
        alwaysHidden.autosaveName = MenuBarControlIdentifier.alwaysHidden
        alwaysHidden.button?.target = self
        alwaysHidden.button?.action = #selector(toggleAlwaysHiddenFromStatusItem)
        alwaysHidden.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        alwaysHidden.button?.toolTip = "macMender Always Hidden divider"
        alwaysHiddenConstraint = Self.controlItemConstraint(for: alwaysHidden.button)
        alwaysHiddenControl = alwaysHidden

        controlsInstalled = true
        updateAppearance(isExpanded: false)
    }

    func physicalItems() -> [MenuBarPhysicalItem] {
        [
            physicalItem(for: hiddenControl, title: MenuBarControlIdentifier.hidden),
            physicalItem(for: alwaysHiddenControl, title: MenuBarControlIdentifier.alwaysHidden)
        ].compactMap(\.self)
    }

    func remove() {
        if let hiddenControl {
            NSStatusBar.system.removeStatusItem(hiddenControl)
        }
        if let alwaysHiddenControl {
            NSStatusBar.system.removeStatusItem(alwaysHiddenControl)
        }
        removeSpacerItems()
        hiddenControl = nil
        alwaysHiddenControl = nil
        hiddenConstraint = nil
        alwaysHiddenConstraint = nil
        controlsInstalled = false
    }

    func showHiddenSection(showAlwaysHiddenDivider: Bool, hasAlwaysHiddenItems: Bool) {
        hiddenControl?.length = Length.standard
        alwaysHiddenControl?.length = hasAlwaysHiddenItems ? Length.expanded : (showAlwaysHiddenDivider ? Length.divider : 0)
        removeSpacerItems()
        hiddenConstraint?.isActive = true
        alwaysHiddenConstraint?.isActive = hasAlwaysHiddenItems || showAlwaysHiddenDivider
        if !hasAlwaysHiddenItems && !showAlwaysHiddenDivider {
            shrinkControlWindow(alwaysHiddenControl)
        }
        updateAppearance(isExpanded: true)
    }

    func hideHiddenSection(hasHiddenItems: Bool, hasAlwaysHiddenItems: Bool) {
        guard hasHiddenItems else {
            hiddenControl?.length = Length.standard
            alwaysHiddenControl?.length = hasAlwaysHiddenItems ? Length.expanded : (layout.showSectionDividers ? Length.divider : 0)
            removeSpacerItems()
            hiddenConstraint?.isActive = true
            alwaysHiddenConstraint?.isActive = hasAlwaysHiddenItems || layout.showSectionDividers
            if !hasAlwaysHiddenItems && !layout.showSectionDividers {
                shrinkControlWindow(alwaysHiddenControl)
            }
            updateAppearance(isExpanded: layout.showSectionDividers)
            return
        }
        hiddenControl?.length = Length.expanded
        alwaysHiddenControl?.length = hasAlwaysHiddenItems ? Length.expanded : (layout.showSectionDividers ? Length.divider : 0)
        installSpacerItemsIfNeeded()
        hiddenConstraint?.isActive = true
        alwaysHiddenConstraint?.isActive = hasAlwaysHiddenItems || layout.showSectionDividers
        updateAppearance(isExpanded: false)
    }

    func showAlwaysHiddenSection() {
        hiddenControl?.length = Length.standard
        alwaysHiddenControl?.length = Length.standard
        removeSpacerItems()
        hiddenConstraint?.isActive = true
        alwaysHiddenConstraint?.isActive = true
        updateAppearance(isExpanded: true)
    }

    func update(layout: MenuBarLayout, isExpanded: Bool) {
        self.layout = layout
        updateAppearance(isExpanded: isExpanded)
    }

    private func updateAppearance(isExpanded: Bool) {
        hiddenControl?.button?.toolTip = isExpanded ? "Hide selected menu-bar icons" : "Reveal selected menu-bar icons"
        alwaysHiddenControl?.button?.toolTip = "Reveal Always Hidden menu-bar icons"

        if !isExpanded {
            hiddenControl?.button?.cell?.isEnabled = false
            alwaysHiddenControl?.button?.cell?.isEnabled = false
            hiddenControl?.button?.isEnabled = false
            alwaysHiddenControl?.button?.isEnabled = false
            hiddenControl?.button?.alphaValue = 0
            alwaysHiddenControl?.button?.alphaValue = 0
            hiddenControl?.button?.isHighlighted = false
            alwaysHiddenControl?.button?.isHighlighted = false
            hiddenControl?.button?.image = nil
            alwaysHiddenControl?.button?.image = nil
        } else if layout.showSectionDividers {
            hiddenControl?.button?.cell?.isEnabled = true
            alwaysHiddenControl?.button?.cell?.isEnabled = true
            hiddenControl?.button?.isEnabled = true
            alwaysHiddenControl?.button?.isEnabled = true
            hiddenControl?.button?.alphaValue = 1
            alwaysHiddenControl?.button?.alphaValue = 1
            hiddenControl?.button?.image = dividerImage(symbolName: "chevron.left")
            alwaysHiddenControl?.button?.image = dividerImage(symbolName: "chevron.compact.left")
        } else {
            hiddenControl?.button?.cell?.isEnabled = true
            alwaysHiddenControl?.button?.cell?.isEnabled = true
            hiddenControl?.button?.isEnabled = true
            alwaysHiddenControl?.button?.isEnabled = true
            hiddenControl?.button?.alphaValue = 1
            alwaysHiddenControl?.button?.alphaValue = 1
            hiddenControl?.button?.image = nil
            alwaysHiddenControl?.button?.image = nil
        }
    }

    private func physicalItem(for statusItem: NSStatusItem?, title: String) -> MenuBarPhysicalItem? {
        guard let window = statusItem?.button?.window else { return nil }
        let windowNumber = window.windowNumber
        let windowID = if windowNumber > 0, windowNumber <= Int(UInt32.max) {
            CGWindowID(windowNumber)
        } else {
            CGWindowID(0)
        }
        let frame = MenuBarPrivateBridge.frame(for: windowID) ?? window.frame
        let info = MenuBarWindowInfo(
            windowID: windowID,
            frame: frame,
            title: title,
            ownerPID: ProcessInfo.processInfo.processIdentifier,
            ownerName: "macMender",
            isOnScreen: true
        )
        return MenuBarPhysicalItem(controlWindow: info)
    }

    private func dividerImage(symbolName: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        image?.isTemplate = true
        image?.size = NSSize(width: 12, height: 12)
        return image
    }

    private static func controlItemConstraint(for button: NSStatusBarButton?) -> NSLayoutConstraint? {
        guard let button,
              let contentView = button.window?.contentView else { return nil }
        return contentView
            .constraintsAffectingLayout(for: .horizontal)
            .first { $0.secondItem === button.superview }
    }

    private func shrinkControlWindow(_ statusItem: NSStatusItem?) {
        guard let window = statusItem?.button?.window else { return }
        var size = window.frame.size
        size.width = 1
        window.setContentSize(size)
    }

    private func installSpacerItemsIfNeeded() {
        let maxScreenWidth = NSScreen.screens.map(\.frame.width).max() ?? 0
        guard maxScreenWidth > 5_120 else {
            removeSpacerItems()
            return
        }

        let desiredWidth = maxScreenWidth * 3
        let remainingWidth = desiredWidth - Length.expanded
        guard remainingWidth > 0 else {
            removeSpacerItems()
            return
        }

        let spacerCount = Int(ceil(remainingWidth / Length.expanded))
        guard spacerItems.isEmpty else {
            spacerItems.forEach { $0.length = Length.expanded }
            return
        }
        spacerItems = (0..<spacerCount).map { index in
            let item = NSStatusBar.system.statusItem(withLength: 0)
            item.autosaveName = "\(MenuBarControlIdentifier.hidden).Spacer.\(index)"
            item.button?.title = ""
            item.button?.image = nil
            item.button?.isEnabled = false
            item.button?.alphaValue = 0
            item.length = Length.expanded
            return item
        }
    }

    private func removeSpacerItems() {
        for item in spacerItems {
            NSStatusBar.system.removeStatusItem(item)
        }
        spacerItems.removeAll()
    }

    private func setPreferredPosition(_ position: CGFloat, autosaveName: String) {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        let current = UserDefaults.standard.object(forKey: key) as? Double
        if current == nil || current.map({ abs($0 - Double(position)) > 1 }) == true {
            UserDefaults.standard.set(position, forKey: key)
        }
    }

    private func clearPreferredPosition(autosaveName: String) {
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position \(autosaveName)")
    }

    @objc private func toggleHiddenFromStatusItem() {
        if NSEvent.modifierFlags.contains(.option) {
            delegate?.menuBarControlItemControllerDidToggleAlwaysHiddenSection(self)
        } else {
            delegate?.menuBarControlItemControllerDidToggleHiddenSection(self)
        }
    }

    @objc private func toggleAlwaysHiddenFromStatusItem() {
        delegate?.menuBarControlItemControllerDidToggleAlwaysHiddenSection(self)
    }
}
