import AppKit
import SwiftUI

struct OnboardingStepRail: View {
    @Binding var selection: OnboardingStep?
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityShowBorders) private var showBorders
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var currentStep: OnboardingStep {
        selection ?? .welcome
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Label("Set Up macMender", systemImage: "arrow.right")
                    .font(.headline)
                Text("A quick tour of the essentials")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, MacMenderSpacing.section)
            .padding(.top, MacMenderSpacing.section)
            .padding(.bottom, MacMenderSpacing.small)

            List(selection: $selection) {
                ForEach(OnboardingStep.allCases) { candidate in
                    HStack(spacing: MacMenderSpacing.standard) {
                        Image(systemName: candidate.systemImage)
                            .font(.callout.weight(.medium))
                            .frame(width: 20)
                            .foregroundStyle(stepIconColor(for: candidate))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.shortTitle)
                                .font(.callout.weight(.medium))
                            Text(candidate.railSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: MacMenderSpacing.compact)

                        if candidate == currentStep {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(emphasizesSelection ? Color.primary : Color.accentColor)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, MacMenderSpacing.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                    .tag(candidate)
                    .listRowBackground(stepBackground(for: candidate))
                    .accessibilityLabel(
                        "Step \(candidate.rawValue + 1), \(candidate.shortTitle), \(candidate.railSubtitle)\(candidate == currentStep ? ", current step" : "")"
                    )
                    .accessibilityAddTraits(candidate == currentStep ? .isSelected : [])
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
                ProgressView(
                    value: Double(currentStep.rawValue + 1),
                    total: Double(OnboardingStep.allCases.count)
                )
                Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(MacMenderSpacing.section)
        }
        .frame(width: 238)
        .macMenderGlassSurface(radius: 0)
    }

    private var emphasizesSelection: Bool {
        differentiateWithoutColor || showBorders || colorSchemeContrast == .increased
    }

    private func stepIconColor(for candidate: OnboardingStep) -> Color {
        guard candidate == currentStep else { return .secondary }
        return emphasizesSelection ? .primary : .accentColor
    }

    @ViewBuilder
    private func stepBackground(for candidate: OnboardingStep) -> some View {
        if candidate == currentStep {
            RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous)
                .fill(Color.accentColor.opacity(emphasizesSelection ? 0.20 : 0.12))
                .overlay {
                    if emphasizesSelection {
                        RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.8), lineWidth: 2)
                    }
                }
        } else {
            Color.clear
        }
    }
}

struct OnboardingStatusItem: Identifiable {
    var title: String
    var tone: MacMenderStatusTone
    var systemImage: String

    var id: String { "\(systemImage):\(title)" }
}

struct OnboardingStatusGroup: View {
    var items: [OnboardingStatusItem]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: MacMenderSpacing.small) {
                labels
            }

            VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
                labels
            }
        }
    }

    @ViewBuilder
    private var labels: some View {
        ForEach(items) { item in
            MacMenderStatusLabel(
                title: item.title,
                tone: item.tone,
                systemImage: item.systemImage
            )
        }
    }
}

struct OnboardingMendyMoment<Content: View>: View {
    var mood: MendyMood
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: MacMenderSpacing.page) {
                mendy
                message
            }

            VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                mendy
                message
            }
        }
        .padding(MacMenderSpacing.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macMenderContentSurface(radius: MacMenderRadius.prominent)
    }

    private var mendy: some View {
        MendyAvatarView(mood: mood, size: 112, showsGlass: false)
            .accessibilitySortPriority(1)
    }

    private var message: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingFeatureItem: View {
    var title: String
    var detail: String
    var systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

struct OnboardingDiagramItem: Identifiable {
    var title: String
    var systemImage: String

    var id: String { title }
}

struct OnboardingFlowDiagram: View {
    var items: [OnboardingDiagramItem]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .accessibilityElement(children: .contain)
    }

    private var horizontalLayout: some View {
        HStack(spacing: MacMenderSpacing.standard) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                OnboardingDiagramNode(item: item)
                if index < items.count - 1 {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
            ForEach(items) { item in
                OnboardingDiagramNode(item: item)
            }
        }
    }
}

private struct OnboardingDiagramNode: View {
    var item: OnboardingDiagramItem

    var body: some View {
        Label(item.title, systemImage: item.systemImage)
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, MacMenderSpacing.standard)
            .padding(.vertical, MacMenderSpacing.small)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
            }
    }
}

struct OnboardingSummaryRow: View {
    var title: String
    var detail: String? = nil
    var status: String
    var tone: MacMenderStatusTone
    var systemImage: String

    var body: some View {
        MacMenderSettingsRow(title: title, detail: detail) {
            MacMenderStatusLabel(title: status, tone: tone, systemImage: systemImage)
        }
    }
}

struct OnboardingPermissionRow<Accessory: View>: View {
    var title: String
    var detail: String
    var state: PermissionState
    var summary: FeatureStatusSummary?
    var systemImage: String
    var primaryTitle: String
    var secondaryTitle: String
    var primaryAction: () -> Void
    var secondaryAction: () -> Void
    @ViewBuilder var accessory: Accessory

    init(
        title: String,
        detail: String,
        state: PermissionState,
        summary: FeatureStatusSummary? = nil,
        systemImage: String,
        primaryTitle: String,
        secondaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.detail = detail
        self.state = state
        self.summary = summary
        self.systemImage = systemImage
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.accessory = accessory()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
            compactLayout
        }
        .padding(.vertical, MacMenderSpacing.standard)
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
            permissionDescription
            Spacer(minLength: MacMenderSpacing.standard)
            permissionAction
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            permissionDescription
            permissionAction
        }
    }

    private var permissionDescription: some View {
        HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(tone.color)
                .frame(width: 32, height: 32)
                .background(tone.color.opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                HStack(spacing: MacMenderSpacing.small) {
                    Text(title)
                        .font(.headline)
                    MacMenderStatusLabel(
                        title: summary?.title ?? state.title,
                        tone: tone
                    )
                    accessory
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var permissionAction: some View {
        if state == .granted {
            openSettingsButton
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: MacMenderSpacing.small) {
                    requestAccessButton
                    openSettingsButton
                }

                VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
                    requestAccessButton
                    openSettingsButton
                }
            }
        }
    }

    private var requestAccessButton: some View {
        Button(primaryTitle, action: primaryAction)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Request \(title) access")
    }

    private var openSettingsButton: some View {
        Button(secondaryTitle, action: secondaryAction)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Open \(title) settings")
    }

    private var tone: MacMenderStatusTone {
        if let summary {
            return MacMenderStatusTone(featureStatusKind: summary.kind)
        }
        return state == .granted ? .active : .attention
    }
}

struct PermissionDragToAddGuide: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateArrow = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
            compactLayout
        }
        .onAppear {
            guard !reduceMotion else { return }
            animateArrow = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                animateArrow = true
            }
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .center, spacing: MacMenderSpacing.section) {
            guideVisuals
                .frame(minWidth: 380)

            instructions
                .frame(minWidth: 230, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
            guideVisuals
            instructions
        }
    }

    private var guideVisuals: some View {
        HStack(alignment: .center, spacing: MacMenderSpacing.standard) {
            DraggableAppTile()
            arrow
            PrivacyListMockup()
        }
        .frame(maxWidth: .infinity, minHeight: 146, alignment: .center)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 24)
            .offset(x: reduceMotion ? 0 : (animateArrow ? 0 : -8))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: animateArrow)
            .accessibilityHidden(true)
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
            NumberedInstruction(number: 1, title: "Open the right Privacy & Security pane from macMender.")
            NumberedInstruction(number: 2, title: "Look for macMender in the permission list.")
            NumberedInstruction(number: 3, title: "If macMender is not listed, use the + button or drag the app in if macOS allows it.")
            NumberedInstruction(number: 4, title: "Turn the toggle on, then return here and recheck.")
            Text("If macOS asks you to reopen macMender, reopen it and continue setup from this step.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DraggableAppTile: View {
    private var appURL: URL {
        Bundle.main.bundleURL
    }

    private var appIcon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }

    var body: some View {
        VStack(spacing: MacMenderSpacing.small) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 58, height: 58)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

            Text("macMender")
                .font(.headline)
            Text("Drag if macOS allows it")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 166, height: 142)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
        .contentShape(.rect)
        .onDrag {
            NSItemProvider(object: appURL as NSURL)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("macMender app, draggable into the macOS permission list")
        .accessibilityHint("Drag this app into Privacy & Security if macOS allows it")
    }
}

private struct PrivacyListMockup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
            Text("Privacy & Security")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            PrivacyMockRow(title: "Finder", enabled: true)
            PrivacyMockRow(title: "macMender", enabled: false, highlighted: true)
            PrivacyMockRow(title: "Other App", enabled: true)
            Text("Add macMender here")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
        }
        .padding(MacMenderSpacing.standard)
        .frame(width: 166)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MacMenderRadius.content, style: .continuous)
                .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example Privacy and Security list with macMender highlighted")
    }
}

private struct PrivacyMockRow: View {
    var title: String
    var enabled: Bool
    var highlighted: Bool = false

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(highlighted ? Color.accentColor.opacity(0.40) : .secondary.opacity(0.25))
                .frame(width: 18, height: 18)
            Text(title)
                .font(.caption)
            Spacer()
            Capsule()
                .fill(enabled ? Color.green.opacity(0.75) : .secondary.opacity(0.25))
                .frame(width: 28, height: 16)
        }
    }
}

private struct NumberedInstruction: View {
    var number: Int
    var title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MacMenderSpacing.small) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title)")
    }
}
