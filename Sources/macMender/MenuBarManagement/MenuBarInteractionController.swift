import AppKit

@MainActor
protocol MenuBarInteractionControllerDelegate: AnyObject {
    func menuBarInteractionControllerDidMovePointer(_ controller: MenuBarInteractionController)
    func menuBarInteractionControllerDidPressMouse(_ controller: MenuBarInteractionController, event: NSEvent)
    func menuBarInteractionControllerDidReleaseMouse(_ controller: MenuBarInteractionController, event: NSEvent)
    func menuBarInteractionControllerDidScroll(_ controller: MenuBarInteractionController, event: NSEvent)
    func menuBarInteractionControllerDidTick(_ controller: MenuBarInteractionController)
}

/// Owns Ice-style local/global event monitoring while keeping reveal policy in the manager.
@MainActor
final class MenuBarInteractionController {
    weak var delegate: MenuBarInteractionControllerDelegate?

    private var monitors: [Any] = []
    private var revealTimer: Timer?

    var isRunning: Bool {
        !monitors.isEmpty || revealTimer != nil
    }

    func start() {
        guard monitors.isEmpty else { return }

        addMonitor(mask: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            guard let self else { return }
            self.delegate?.menuBarInteractionControllerDidMovePointer(self)
        }
        addMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            self.delegate?.menuBarInteractionControllerDidPressMouse(self, event: event)
        }
        addMonitor(mask: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { [weak self] event in
            guard let self else { return }
            self.delegate?.menuBarInteractionControllerDidReleaseMouse(self, event: event)
        }
        addMonitor(mask: [.scrollWheel]) { [weak self] event in
            guard let self else { return }
            self.delegate?.menuBarInteractionControllerDidScroll(self, event: event)
        }

        revealTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.delegate?.menuBarInteractionControllerDidTick(self)
            }
        }
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        revealTimer?.invalidate()
        revealTimer = nil
    }

    private func addMonitor(mask: NSEvent.EventTypeMask, handler: @escaping @MainActor (NSEvent) -> Void) {
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            Task { @MainActor in
                handler(event)
            }
            return event
        }) {
            monitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
            Task { @MainActor in
                handler(event)
            }
        }) {
            monitors.append(global)
        }
    }
}
