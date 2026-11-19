import AppKit
import CoreGraphics

/// Intercepts key presses while a Dock preview is open, so arrow keys can drive a panel that
/// never becomes the key window. The handler decides, per key, whether the press is consumed.
@MainActor
final class DockPreviewKeyTap {
    /// Returns `true` to consume the key press.
    var handler: ((_ keyCode: Int64, _ flags: CGEventFlags) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    func start() {
        guard tap == nil else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: Self.callback,
            userInfo: refcon
        ) else {
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        // The tap's source is on the main run loop, so this runs on the main thread.
        let keyTap = Unmanaged<DockPreviewKeyTap>.fromOpaque(refcon).takeUnretainedValue()
        let consumed = MainActor.assumeIsolated {
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = keyTap.tap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return false
            }
            guard type == .keyDown else { return false }
            return keyTap.handler?(keyCode, flags) ?? false
        }
        return consumed ? nil : Unmanaged.passUnretained(event)
    }
}

/// Shows one window at full size, behind the Dock preview, while the pointer rests on its card.
@MainActor
final class DockPreviewPeekPanel {
    private var panel: NSPanel?
    private var hideGeneration = 0
    private(set) var isVisible = false

    func show(image: CGImage, frame: CGRect, level: NSWindow.Level, animated: Bool) {
        guard frame.width > 1, frame.height > 1 else { return }
        let panel = ensurePanel()
        hideGeneration += 1
        panel.level = level
        panel.contentView?.layer?.contents = image
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
        if !isVisible {
            panel.alphaValue = animated ? 0 : 1
            panel.orderFrontRegardless()
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.14
                    panel.animator().alphaValue = 1
                }
            }
        }
        isVisible = true
    }

    func hide(animated: Bool = true) {
        guard isVisible, let panel else { return }
        isVisible = false
        hideGeneration += 1
        let generation = hideGeneration
        guard animated else {
            panel.orderOut(nil)
            panel.contentView?.layer?.contents = nil
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.hideGeneration == generation else { return }
                panel.orderOut(nil)
                panel.contentView?.layer?.contents = nil
            }
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
        let view = NSView()
        view.wantsLayer = true
        view.layer?.contentsGravity = .resize
        view.layer?.cornerRadius = 10
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        panel.contentView = view
        self.panel = panel
        return panel
    }
}
