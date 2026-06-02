import SwiftUI

struct AdvancedView: View {
    @ObservedObject var appModel: AppModel
    @State private var showingResetConfirmation = false

    var body: some View {
        PreferencesScrollView {
            SectionCard(title: "Local Diagnostics", subtitle: "Messages stay on this Mac.", symbolName: "stethoscope") {
                VStack(alignment: .leading, spacing: 8) {
                    if appModel.diagnostics.latestMessages.isEmpty {
                        Label("No recent diagnostics", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        DisclosureGroup("Recent local messages") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(appModel.diagnostics.latestMessages, id: \.self) { message in
                                    Label(message, systemImage: "info.circle")
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.top, 6)
                        }
                    }
                }
            }

            SectionCard(title: "Recovery Tools", subtitle: "Safe, reversible actions for troubleshooting.", symbolName: "arrow.counterclockwise") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Safe Mode")
                                .font(.callout.weight(.semibold))
                            Text("Pauses active input monitoring, Dock previews, Window Switcher shortcuts, and experimental input features. App settings and this window stay available.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        Button(appModel.store.config.safeModeEnabled ? "Disable Safe Mode" : "Enable Safe Mode") {
                            appModel.toggleSafeMode()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .liquidGlass(.row)

                    HStack {
                        Button("Read Dock Defaults") {
                            appModel.dock.refresh()
                        }
                        Button("Save Configuration") {
                            appModel.store.save()
                        }
                        Button("Export Configuration") {
                            appModel.exportConfiguration()
                        }
                        Spacer()
                        Button("Reset to Onboarding", role: .destructive) {
                            showingResetConfirmation = true
                        }
                    }
                }
            }

            SectionCard(title: "Technical Status", subtitle: "Detailed boundaries are available when you need them.", symbolName: "lock.trianglebadge.exclamationmark") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Only verified controls are shown as available.", systemImage: "checkmark.shield")
                        .foregroundStyle(.secondary)

                    DisclosureGroup("Technical boundaries") {
                        VStack(alignment: .leading, spacing: 8) {
                            BoundaryRow(title: "Launch timing", detail: launchTimingDetail)
                            BoundaryRow(title: "Dock icon hover previews", detail: "Reads the Dock accessibility tree and disables itself when Accessibility is unavailable.")
                            BoundaryRow(title: "Three-finger global gestures", detail: "Uses local multitouch callbacks where available and falls back to mouse-button triggers otherwise.")
                            BoundaryRow(title: "Spaces movement", detail: "Only actions with a reliable local runtime path are exposed in the UI.")
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
        .confirmationDialog("Reset macMender?", isPresented: $showingResetConfirmation) {
            Button("Reset to Onboarding", role: .destructive) {
                appModel.resetToOnboarding()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears local settings and shows onboarding again.")
        }
    }

    private var launchTimingDetail: String {
        let firstWindow = appModel.firstWindowReadyAt.map { "first window marked \($0.formatted(date: .omitted, time: .standard))" } ?? "first window not marked yet"
        let runtime = appModel.runtimeStartedAt.map { "runtime started \($0.formatted(date: .omitted, time: .standard))" } ?? "runtime not started yet"
        return "\(firstWindow); \(runtime). Heavier helpers start after the first window appears."
    }
}

private struct BoundaryRow: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.row)
    }
}
