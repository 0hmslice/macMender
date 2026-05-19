import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import ScreenCaptureKit

@MainActor
final class PermissionService: ObservableObject {
    @Published private(set) var accessibility: PermissionState = .missing
    @Published private(set) var screenRecording: PermissionState = .missing

    private var screenRecordingProbeTask: Task<Void, Never>?

    var needsAttention: Bool {
        accessibility != .granted || screenRecording != .granted
    }

    func refresh() {
        accessibility = AXIsProcessTrusted() ? .granted : .missing
        if CGPreflightScreenCaptureAccess() {
            screenRecordingProbeTask?.cancel()
            screenRecording = .granted
        } else {
            screenRecording = .missing
            probeScreenCaptureKitAccess()
        }
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        refresh()
    }

    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        refreshScreenRecordingAfterTCCChange()
    }

    func openAccessibilitySettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        refreshScreenRecordingAfterTCCChange()
    }

    private func openSettingsPane(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private func probeScreenCaptureKitAccess() {
        guard screenRecordingProbeTask == nil else { return }
        screenRecordingProbeTask = Task { @MainActor [weak self] in
            defer { self?.screenRecordingProbeTask = nil }

            do {
                let content = try await SCShareableContent.current
                guard !Task.isCancelled else { return }
                if !content.displays.isEmpty || !content.windows.isEmpty {
                    self?.screenRecording = .granted
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.screenRecording = .missing
            }
        }
    }

    private func refreshScreenRecordingAfterTCCChange() {
        Task { @MainActor [weak self] in
            for delay in [0.25, 1.0, 2.0] {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                self?.refresh()
            }
        }
    }
}
