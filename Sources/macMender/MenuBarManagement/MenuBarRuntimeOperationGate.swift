import Foundation

/// Serializes physical menu-bar operations.
///
/// Thaw's runtime avoids overlapping discovery, restore, and move work because
/// WindowServer status-item frames can be temporarily invalid while a section is
/// expanding or collapsing. macMender keeps the same rule at the app adapter
/// boundary: every physical move/restore runs after the previous one settles.
@MainActor
final class MenuBarRuntimeOperationGate {
    private var tail: Task<Void, Never>?

    func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = tail
        tail = Task { @MainActor in
            await previous?.value
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    func cancelAll() {
        tail?.cancel()
        tail = nil
    }
}
