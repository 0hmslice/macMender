import SwiftUI

struct AdvancedStatusRefreshRow: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        SettingsRow(
            title: appModel.isRefreshingStatus ? "Checking…" : lastUpdatedTitle,
            detail: statusSummary
        ) {
            if appModel.isRefreshingStatus {
                ProgressView().controlSize(.small)
            }
            Button("Check Now") { appModel.refreshStatus() }
                .disabled(appModel.isRefreshingStatus)
        }
    }

    private var lastUpdatedTitle: String {
        guard let last = appModel.lastStatusRefresh else {
            return "Status not checked yet"
        }
        if Date().timeIntervalSince(last) < 60 {
            return "Updated just now"
        }
        return "Updated at \(last.formatted(date: .omitted, time: .shortened))"
    }

    private var statusSummary: String {
        guard appModel.lastStatusRefresh != nil else {
            return "Re-reads permissions, the login item, and the Dock."
        }
        return appModel.lastStatusRefreshSummary
    }
}

struct AdvancedRuntimeRow: View {
    var title: String
    var summary: FeatureStatusSummary

    var body: some View {
        SettingsRow(title: title, detail: summary.detail) {
            SettingsStatusBadge(title: summary.title, tone: MacMenderStatusTone(featureStatusKind: summary.kind))
        }
    }
}
