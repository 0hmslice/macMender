import SwiftUI

struct WindowDiscoveryDiagnosticsView: View {
    var report: WindowDiscoveryReport
    var hasRunDiscovery: Bool
    var activationDiagnostic: String

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
                Text("Activation: \(activationDiagnostic)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if !hasRunDiscovery {
                    Text("No scan yet. Run Refresh Windows to list windows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if report.appReports.isEmpty {
                    Text("No switchable windows were found in the last scan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.appReports.filter(shouldShowReport)) { appReport in
                        VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                            Text("\(appReport.appName)  bundle=\(appReport.bundleIdentifier ?? "nil")  pid=\(appReport.processIdentifier)")
                                .font(.caption.weight(.semibold))
                                .textSelection(.enabled)
                            Text("AX windows: \(appReport.axWindowCount)  CG-only: \(appReport.cgOnlyWindowCount)  included: \(appReport.includedCount)  dropped: \(appReport.droppedCount)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            ForEach(Array(appReport.entries.prefix(6))) { entry in
                                WindowDiscoveryEntryLineView(entry: entry)
                            }
                            if appReport.entries.count > 6 {
                                Text("\(appReport.entries.count - 6) more windows omitted")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let reason = appReport.appDropReason {
                                Text("App drop reason: \(reason)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, MacMenderSpacing.compact)
                    }
                }
            }
            .padding(.top, MacMenderSpacing.small)
        } label: {
            Label("Discovery Diagnostics: \(diagnosticsSummary)", systemImage: "list.bullet.rectangle")
                .font(.caption.weight(.semibold))
        }
    }

    private var diagnosticsSummary: String {
        hasRunDiscovery ? report.summary : "No scan yet"
    }

    private func shouldShowReport(_ report: WindowAppDiscoveryReport) -> Bool {
        report.axWindowCount > 0 || report.cgOnlyWindowCount > 0 || report.includedCount > 0 || report.appDropReason != nil
    }
}

private struct WindowDiscoveryEntryLineView: View {
    var entry: WindowDiscoveryEntry

    var body: some View {
        Text(entryLine)
            .font(.caption2.monospaced())
            .foregroundStyle(entry.included ? Color.secondary : Color.primary)
            .textSelection(.enabled)
    }

    private var entryLine: String {
        let state = entry.included ? "included" : "dropped"
        let cgID = entry.cgWindowID.map(String.init) ?? "missing"
        let match = entry.cgMatchFound ? "found" : "missing"
        return "• \(state) title=\"\(entry.title)\" cg=\(cgID) match=\(match) reason=\(entry.reason)"
    }
}

struct DockSettingsPreview: View {
    var settings: DockSettings

    /// Scales the largest possible icon to fit the preview's height.
    private static let scale = 0.5

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<8, id: \.self) { index in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: dockItemSize(index) * 0.24, style: .continuous)
                        .fill(index == 2 ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.secondary.opacity(0.28)))
                        .frame(width: dockItemSize(index), height: dockItemSize(index))
                    Circle()
                        .fill(.primary.opacity(settings.showIndicators && [1, 2, 4].contains(index) ? 0.6 : 0))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .bottom)
        .animation(.snappy(duration: 0.2), value: settings)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previewAccessibilityLabel)
    }

    private var previewAccessibilityLabel: String {
        let magnification = settings.magnificationEnabled ? "on" : "off"
        let indicators = settings.showIndicators ? "shown" : "hidden"
        return "Dock illustration. Position \(settings.position.title), size \(Int(settings.size)), magnification \(magnification), open app indicators \(indicators)."
    }

    private func dockItemSize(_ index: Int) -> Double {
        guard settings.magnificationEnabled, index == 2 else { return settings.size * Self.scale }
        return max(settings.magnificationSize, settings.size) * Self.scale
    }
}

struct DockProfilesDisclosure: View {
    var profiles: [MacMenderProfile]
    var activeProfileID: UUID

    var body: some View {
        DisclosureGroup("Dock settings in each profile") {
            VStack(spacing: 0) {
                ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                    HStack(spacing: MacMenderSpacing.standard) {
                        Label(profile.name, systemImage: profile.symbolName)
                        Spacer()
                        if profile.id == activeProfileID {
                            SettingsStatusBadge(title: "Active", tone: .active)
                        }
                        Text("\(profile.dock.position.title), \(Int(profile.dock.size)) pt")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, MacMenderSpacing.small)

                    if index < profiles.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.top, MacMenderSpacing.small)
        }
    }
}
