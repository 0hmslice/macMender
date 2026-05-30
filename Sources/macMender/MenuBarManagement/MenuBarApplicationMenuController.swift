import AppKit
import ApplicationServices

/// Handles the Ice behavior that temporarily hides application menus when revealed
/// status items would collide with the app's menu titles.
@MainActor
final class MenuBarApplicationMenuController {
    private var isHidingApplicationMenus = false

    func isMouseInsideApplicationMenu(_ mouseLocation: CGPoint) -> Bool {
        guard let frame = applicationMenuFrame() else { return false }
        return frame.insetBy(dx: 4, dy: 4).contains(mouseLocation)
    }

    func hideIfNeeded(visibleItems: [MenuBarPhysicalItem], enabled: Bool) {
        guard enabled,
              !isHidingApplicationMenus,
              NSApp.windows.allSatisfy({ !$0.isVisible || $0.title != "macMender" }),
              let applicationMenuFrame = applicationMenuFrame(),
              let leftmost = visibleItems.min(by: { $0.frame.minX < $1.frame.minX }),
              leftmost.frame.minX <= applicationMenuFrame.maxX else {
            return
        }

        // Do not change macMender's activation policy here. Earlier builds
        // briefly activated macMender as an accessory app to collapse the
        // frontmost app menus; that made the preferences window behave like a
        // background helper window when "Hide Dock icon" was enabled.
        isHidingApplicationMenus = true
    }

    func restoreIfNeeded() {
        guard isHidingApplicationMenus else { return }
        isHidingApplicationMenus = false
    }

    private func applicationMenuFrame() -> CGRect? {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(frontmost.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.06)
        let menuBar = axChildren(of: element).first { axString($0, kAXRoleAttribute) == kAXMenuBarRole }
        guard let menuBar else { return nil }

        let enabledItems = axChildren(of: menuBar).filter {
            axString($0, kAXRoleAttribute) == kAXMenuBarItemRole && axString($0, kAXSubroleAttribute) != "AXMenuExtra"
        }
        let frame = enabledItems.reduce(CGRect.null) { partial, item in
            partial.union(axFrame(of: item))
        }
        guard !frame.isNull, frame.width > 0 else { return nil }
        return frame
    }

    private func axChildren(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            return []
        }
        return children
    }

    private func axString(_ element: AXUIElement, _ attribute: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return ""
        }
        return value as? String ?? ""
    }

    private func axFrame(of element: AXUIElement) -> CGRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue else {
            return .zero
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }
}
