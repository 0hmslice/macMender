import AppKit
import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var appModel: AppModel
    var openSettingsAction: (() -> Void)?
    var closeAction: (() -> Void)?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                MendyAvatarView(mood: appModel.menuBarMendyMood, size: 54)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appModel.runningStatusTitle)
                        .font(.headline)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Divider()

            Button {
                closeAction?()
                dismiss()
                DispatchQueue.main.async {
                    if let openSettingsAction {
                        openSettingsAction()
                    } else {
                        if !appModel.focusPreferencesWindow() {
                            openWindow(id: "preferences")
                        }
                        appModel.activateApp()
                    }
                }
            } label: {
                Label(
                    appModel.store.config.hasCompletedOnboarding ? "Open Settings" : "Continue Setup",
                    systemImage: "gearshape"
                )
            }
            .buttonStyle(LiquidGlassButtonStyle())

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit macMender", systemImage: "power")
            }
            .buttonStyle(LiquidGlassButtonStyle())
        }
        .padding()
        .frame(width: 300)
        .liquidGlass(.panel)
    }

    private var statusDetail: String {
        if appModel.store.config.hasCompletedOnboarding,
           !appModel.store.config.safeModeEnabled,
           appModel.permissions.accessibility == .granted {
            return "Mendy is keeping your scroll, Dock, and hidden menu-bar icons in sync."
        }
        return appModel.runningStatusDetail
    }
}
