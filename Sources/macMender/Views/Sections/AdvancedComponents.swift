import SwiftUI

struct AdvancedActionRow: View {
    var title: String
    var detail: String
    var buttonTitle: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: MacMenderSpacing.standard)

            Button(buttonTitle, action: action)
                .accessibilityLabel(title)
        }
        .padding(.vertical, MacMenderSpacing.small)
    }
}

struct AdvancedStatusRefreshRow: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
            Group {
                if appModel.isRefreshingStatus {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing status")
                } else {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(appModel.isRefreshingStatus ? "Updating status…" : lastUpdatedTitle)
                    .font(.body.weight(.medium))
                Text(statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: MacMenderSpacing.standard)

            Button {
                appModel.refreshStatus()
            } label: {
                Label(appModel.isRefreshingStatus ? "Refreshing" : "Refresh Status", systemImage: "arrow.clockwise")
            }
            .disabled(appModel.isRefreshingStatus)
        }
        .padding(.vertical, MacMenderSpacing.small)
    }

    private var lastUpdatedTitle: String {
        guard let last = appModel.lastStatusRefresh else {
            return "Not refreshed yet"
        }
        if Date().timeIntervalSince(last) < 60 {
            return "Updated just now"
        }
        return "Updated at \(last.formatted(date: .omitted, time: .shortened))"
    }

    private var statusSummary: String {
        guard appModel.lastStatusRefresh != nil else {
            return "Refresh when you want to re-read current system state."
        }
        return appModel.lastStatusRefreshSummary
    }
}

struct AdvancedRuntimeRow: View {
    var title: String
    var summary: FeatureStatusSummary

    var body: some View {
        HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(summary.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: MacMenderSpacing.standard)

            MacMenderStatusLabel(
                title: summary.title,
                tone: MacMenderStatusTone(featureStatusKind: summary.kind)
            )
        }
        .padding(.vertical, MacMenderSpacing.small)
    }
}

struct AdvancedBoundaryRow: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
            Text(title)
                .font(.body.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, MacMenderSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
