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

    var body: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            HStack {
                Text("Dock Preview")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(settings.position.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: MacMenderSpacing.small) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous)
                        .fill(index == 2 ? Color.accentColor.opacity(0.72) : Color.secondary.opacity(0.22))
                        .frame(width: dockItemSize(index), height: dockItemSize(index))
                        .overlay(alignment: .bottom) {
                            if settings.showIndicators && [1, 2, 4].contains(index) {
                                Circle()
                                    .fill(.primary.opacity(0.55))
                                    .frame(width: 4, height: 4)
                                    .offset(y: 8)
                            }
                        }
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .center)
        }
        .padding(MacMenderSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macMenderContentSurface(radius: MacMenderRadius.control)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(previewAccessibilityLabel)
    }

    private var previewAccessibilityLabel: String {
        let magnification = settings.magnificationEnabled ? "on" : "off"
        let indicators = settings.showIndicators ? "shown" : "hidden"
        return "Dock preview. Position \(settings.position.title), size \(Int(settings.size)), magnification \(magnification), open app indicators \(indicators)."
    }

    private func dockItemSize(_ index: Int) -> Double {
        guard settings.magnificationEnabled, index == 2 else { return settings.size * 0.7 }
        return settings.magnificationSize * 0.7
    }
}

struct DockProfilesDisclosure: View {
    var profiles: [MacMenderProfile]
    var activeProfileID: UUID

    var body: some View {
        DisclosureGroup("Compare Dock Settings Across Profiles") {
            VStack(spacing: 0) {
                ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                    HStack(spacing: MacMenderSpacing.standard) {
                        Label(profile.name, systemImage: profile.symbolName)
                        Spacer()
                        if profile.id == activeProfileID {
                            MacMenderStatusLabel(title: "Active", tone: .active)
                        }
                        Text("\(profile.dock.position.title), \(Int(profile.dock.size)) px")
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
