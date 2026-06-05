import SwiftUI

struct MenuBarSpacingView: View {
    @ObservedObject var appModel: AppModel
    @State private var pendingPreference: MenuBarSpacingPreference = .systemDefault
    @State private var pendingValue = Double(MenuBarSpacingPreference.systemDefaultNumericValue)

    var body: some View {
        PreferencesScrollView {
            MendySectionHeader(
                section: .menuBarSpacing,
                title: "Menu Bar Spacing",
                subtitle: "Adjust the spacing between menu bar icons."
            )

            SectionCard(
                title: "Spacing",
                subtitle: "This changes the system spacing preference. It does not move, hide, or manage individual icons.",
                symbolName: "arrow.left.and.right"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Preset", selection: presetSelection) {
                        ForEach(MenuBarSpacingPreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(appModel.menuBarSpacing.isApplying)

                    LabeledSlider(
                        title: "Icon spacing",
                        value: spacingValue,
                        range: Double(MenuBarSpacingPreference.minimumValue)...Double(MenuBarSpacingPreference.maximumValue),
                        step: 1,
                        valueLabel: "\(Int(pendingValue.rounded()))"
                    )
                    .disabled(appModel.menuBarSpacing.isApplying)

                    HStack(spacing: 8) {
                        CapabilityBadge(title: pendingPreference.title, systemImage: "slider.horizontal.3", tone: .neutral)
                        Text(currentDefaultsText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button {
                            appModel.applyMenuBarSpacing(pendingPreference, customValue: Int(pendingValue.rounded()))
                        } label: {
                            Label("Apply", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appModel.menuBarSpacing.isApplying)

                        Button {
                            pendingPreference = .systemDefault
                            pendingValue = Double(MenuBarSpacingPreference.systemDefaultNumericValue)
                            appModel.applyMenuBarSpacing(.systemDefault, customValue: Int(pendingValue.rounded()))
                        } label: {
                            Label("Reset to Default", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(appModel.menuBarSpacing.isApplying)

                        Spacer(minLength: 0)
                    }

                    Text(appModel.menuBarSpacing.statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Applying may briefly reload menu bar icons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            appModel.refreshMenuBarSpacingStatus()
            loadPendingState()
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

    private var currentDefaultsText: String {
        appModel.menuBarSpacing.currentValues.description
    }

    private func loadPendingState() {
        let stored = appModel.store.config.appBehavior
        if stored.menuBarSpacing == .systemDefault,
           let currentValue = appModel.menuBarSpacing.currentValues.sharedValue {
            let clamped = MenuBarSpacingPreference.clampedValue(currentValue)
            pendingValue = Double(clamped)
            pendingPreference = MenuBarSpacingPreference.preference(matching: clamped)
            return
        }

        let resolvedValue = stored.menuBarSpacing.resolvedDefaultsValue(customValue: stored.menuBarSpacingCustomValue) ??
            MenuBarSpacingPreference.systemDefaultNumericValue
        pendingValue = Double(resolvedValue)
        pendingPreference = stored.menuBarSpacing == .custom ?
            MenuBarSpacingPreference.preference(matching: resolvedValue) :
            stored.menuBarSpacing
    }
}
