import SwiftUI

struct MenuBarSpacingView: View {
    @ObservedObject var appModel: AppModel
    @State private var pendingPreference: MenuBarSpacingPreference = .systemDefault
    @State private var pendingValue = Double(MenuBarSpacingPreference.systemDefaultNumericValue)

    var body: some View {
        MacMenderScrollablePage(maxContentWidth: 760) {
            MacMenderPageHeader(
                title: "Menu Bar Spacing",
                subtitle: "Adjust spacing for compatible menu bar icons.",
                systemImage: SettingsSection.menuBarSpacing.symbolName
            )

            compatibilitySection
            spacingSection
        }
        .onAppear {
            appModel.refreshMenuBarSpacingStatus()
            loadPendingState()
        }
        .onChange(of: appModel.store.config.appBehavior) { _, _ in
            loadPendingState()
        }
    }

    private var spacingSection: some View {
        MacMenderContentSection(
            title: "Spacing",
            subtitle: "Choose a preset or a precise value. Nothing changes until you press Apply.",
            systemImage: "slider.horizontal.3"
        ) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                MenuBarSpacingPreview(
                    preference: pendingPreference,
                    value: Int(pendingValue.rounded())
                )

                Picker("Preset", selection: presetSelection) {
                    ForEach(MenuBarSpacingPreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(appModel.menuBarSpacing.isApplying)

                LabeledSlider(
                    title: "Icon Spacing",
                    value: spacingValue,
                    range: Double(MenuBarSpacingPreference.minimumValue)...Double(MenuBarSpacingPreference.maximumValue),
                    step: 1,
                    valueLabel: "\(Int(pendingValue.rounded()))"
                )
                .disabled(appModel.menuBarSpacing.isApplying)

                HStack(spacing: MacMenderSpacing.small) {
                    MacMenderStatusLabel(
                        title: selectionTitle,
                        tone: .neutral,
                        systemImage: "slider.horizontal.3"
                    )
                    Text(selectionDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }

                HStack {
                    Button("Apply") {
                        appModel.applyMenuBarSpacing(
                            pendingPreference,
                            customValue: Int(pendingValue.rounded())
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appModel.menuBarSpacing.isApplying)

                    Button {
                        pendingPreference = .systemDefault
                        pendingValue = Double(MenuBarSpacingPreference.systemDefaultNumericValue)
                        appModel.applyMenuBarSpacing(
                            .systemDefault,
                            customValue: Int(pendingValue.rounded())
                        )
                    } label: {
                        Label("Reset to Default", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(appModel.menuBarSpacing.isApplying)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var compatibilitySection: some View {
        MacMenderContentSection(
            title: "Compatibility",
            subtitle: "Availability depends on macOS and the app that owns each icon.",
            systemImage: "stethoscope"
        ) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
                HStack(spacing: MacMenderSpacing.small) {
                    if appModel.menuBarSpacing.isApplying {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Applying menu bar spacing")
                        Text("Applying")
                            .font(.callout.weight(.medium))
                    } else {
                        MacMenderStatusLabel(
                            title: compatibilityTitle,
                            tone: compatibilityTone,
                            systemImage: compatibilitySymbol
                        )
                    }

                    Spacer(minLength: 0)
                }

                Text(appModel.menuBarSpacing.statusDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if appModel.menuBarSpacing.systemContext.majorVersion >= 27 {
                    Link("Spacing research and test results", destination: URL(string: "https://github.com/0hmslice/macMender/blob/main/docs/UPGRADE.md#menu-bar-spacing-current-evidence")!)
                    Text("Tested September 23, 2026: Apple icon positions did not change on macOS 27.0 (26A428), even after restarting MenuBarAgent. Apply does not restart it.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Applying refreshes Control Center and may interrupt screen sharing. Third-party apps may need to be relaunched.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Divider()

                LabeledContent("Your system") {
                    Text(systemDescription)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var presetSelection: Binding<MenuBarSpacingPreference> {
        Binding(
            get: { pendingPreference },
            set: { preference in
                pendingPreference = preference
                if let value = preference.defaultsValue {
                    pendingValue = Double(value)
                } else if preference == .systemDefault {
                    pendingValue = Double(MenuBarSpacingPreference.systemDefaultNumericValue)
                }
            }
        )
    }

    private var spacingValue: Binding<Double> {
        Binding(
            get: { pendingValue },
            set: { value in
                let rounded = MenuBarSpacingPreference.clampedValue(Int(value.rounded()))
                pendingValue = Double(rounded)
                pendingPreference = MenuBarSpacingPreference.preference(matching: rounded)
            }
        )
    }

    private var compatibilityTitle: String {
        appModel.menuBarSpacing.resultKind?.title ?? "Ready to Apply"
    }

    private var selectionTitle: String {
        hasPendingPreferenceChange ? "Pending: \(pendingPreference.title)" : "Selected: \(pendingPreference.title)"
    }

    private var selectionDetail: String {
        hasPendingPreferenceChange ? pendingPreference.detail : "Matches the saved preference."
    }

    private var hasPendingPreferenceChange: Bool {
        let plan = MenuBarSpacingService.defaultsPlan(
            for: pendingPreference,
            customValue: Int(pendingValue.rounded())
        )
        return !appModel.menuBarSpacing.currentValues.matches(plan)
    }

    private var compatibilityTone: MacMenderStatusTone {
        MacMenderStatusTone(menuBarSpacingResultKind: appModel.menuBarSpacing.resultKind)
    }

    private var compatibilitySymbol: String {
        appModel.menuBarSpacing.resultKind == nil ? "info.circle" : compatibilityTone.defaultSymbol
    }

    private var systemDescription: String {
        let system = appModel.menuBarSpacing.systemContext
        return "macOS \(system.majorVersion).\(system.minorVersion).\(system.patchVersion) · build \(system.buildVersion)"
    }

    private func loadPendingState() {
        let stored = appModel.store.config.appBehavior
        let resolvedValue = stored.menuBarSpacing.resolvedDefaultsValue(customValue: stored.menuBarSpacingCustomValue) ??
            MenuBarSpacingPreference.systemDefaultNumericValue
        pendingValue = Double(resolvedValue)
        pendingPreference = stored.menuBarSpacing == .custom ?
            MenuBarSpacingPreference.preference(matching: resolvedValue) :
            stored.menuBarSpacing
    }
}

private struct MenuBarSpacingPreview: View {
    var preference: MenuBarSpacingPreference
    var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            HStack {
                VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                    Text("Preference Preview")
                        .font(.subheadline.weight(.medium))
                    Text(previewCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: MacMenderSpacing.standard)

                Text("Illustrative")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: previewSpacing) {
                Image(systemName: "puzzlepiece.extension")
                Image(systemName: "cloud")
                Image(systemName: "scissors")
                Image(systemName: "cup.and.saucer")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            }
            .accessibilityHidden(true)
        }
        .padding(MacMenderSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macMenderContentSurface(radius: MacMenderRadius.control)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Illustrative menu bar spacing preference preview. \(previewCaption)")
    }

    private var previewSpacing: CGFloat {
        CGFloat(MenuBarSpacingPreference.clampedValue(value))
    }

    private var previewCaption: String {
        if preference == .systemDefault {
            return "System Default removes macMender's override; macOS controls the resulting spacing."
        }
        return "A \(MenuBarSpacingPreference.clampedValue(value))-point preference for compatible status items."
    }
}
