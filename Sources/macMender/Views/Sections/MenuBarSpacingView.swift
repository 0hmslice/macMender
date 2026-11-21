import SwiftUI

struct MenuBarSpacingView: View {
    @ObservedObject var appModel: AppModel
    @State private var pendingPreference: MenuBarSpacingPreference = .systemDefault
    @State private var pendingValue = Double(MenuBarSpacingPreference.systemDefaultNumericValue)

    var body: some View {
        SettingsPage(section: .menuBarSpacing) {
            if let notice = compatibilityNotice {
                Section {
                    Label {
                        Text(notice)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                MenuBarSpacingPreview(
                    preference: pendingPreference,
                    value: Int(pendingValue.rounded())
                )

                Picker("Preset", selection: presetSelection) {
                    ForEach(MenuBarSpacingPreference.allCases.filter { $0 != .custom }) { preference in
                        Text(preference.title).tag(preference)
                    }
                    if pendingPreference == .custom {
                        Text("Custom").tag(MenuBarSpacingPreference.custom)
                    }
                }

                SettingsSlider(
                    title: "Space between icons",
                    value: spacingValue,
                    range: Double(MenuBarSpacingPreference.minimumValue)...Double(MenuBarSpacingPreference.maximumValue),
                    step: 1,
                    valueLabel: pendingPreference == .systemDefault ? "macOS default" : "\(Int(pendingValue.rounded())) pt",
                    minimumLabel: "Tight",
                    maximumLabel: "Roomy"
                )

                HStack {
                    if appModel.menuBarSpacing.isApplying {
                        ProgressView().controlSize(.small)
                        Text("Applying…").foregroundStyle(.secondary)
                    } else {
                        Text(hasPendingPreferenceChange ? "Not applied yet" : "")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Use macOS Default") {
                        pendingPreference = .systemDefault
                        pendingValue = Double(MenuBarSpacingPreference.systemDefaultNumericValue)
                        appModel.applyMenuBarSpacing(.systemDefault, customValue: Int(pendingValue.rounded()))
                    }
                    .disabled(pendingPreference == .systemDefault && !hasPendingPreferenceChange)
                    Button("Apply") {
                        appModel.applyMenuBarSpacing(pendingPreference, customValue: Int(pendingValue.rounded()))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasPendingPreferenceChange)
                }
            } header: {
                Text("Spacing")
            } footer: {
                SettingsFooter("Nothing changes until you press Apply. Other apps may need to be reopened before their icons move. This setting applies to every profile.")
            }
            .disabled(appModel.menuBarSpacing.isApplying)

            if showsLastResult {
              Section("Last Result") {
                SettingsRow(title: compatibilityTitle, detail: appModel.menuBarSpacing.statusDescription) {
                    SettingsStatusBadge(title: compatibilityTone == .active ? "OK" : compatibilityTone.accessibilityTitle, tone: compatibilityTone)
                }
              }
            }
        }
        .onAppear {
            appModel.refreshMenuBarSpacingStatus()
            loadPendingState()
        }
        .onChange(of: appModel.store.config.appBehavior.menuBarSpacing) { _, _ in
            loadPendingState()
        }
        .onChange(of: appModel.store.config.appBehavior.menuBarSpacingCustomValue) { _, _ in
            loadPendingState()
        }
    }

    /// Shown only where spacing is known not to take full effect.
    private var compatibilityNotice: String? {
        guard appModel.menuBarSpacing.systemContext.majorVersion >= 27 else { return nil }
        return "On macOS 27, Apple's own icons (Wi-Fi, sound, battery, Control Center, clock) did not move in testing. macMender's icon and some other apps' icons do."
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



    /// Whether the controls show something other than what was last applied.
    private var hasPendingPreferenceChange: Bool {
        let stored = appModel.store.config.appBehavior
        let storedValue = stored.menuBarSpacing.resolvedDefaultsValue(customValue: stored.menuBarSpacingCustomValue)
            ?? MenuBarSpacingPreference.systemDefaultNumericValue
        if pendingPreference == .systemDefault || stored.menuBarSpacing == .systemDefault {
            return pendingPreference != stored.menuBarSpacing
        }
        return Int(pendingValue.rounded()) != storedValue
    }

    /// The outcome of the last Apply, when it adds something the notice above does not say.
    private var showsLastResult: Bool {
        guard let kind = appModel.menuBarSpacing.resultKind else { return false }
        return kind == .failed || appModel.menuBarSpacing.systemContext.majorVersion < 27
    }

    private var compatibilityTone: MacMenderStatusTone {
        MacMenderStatusTone(menuBarSpacingResultKind: appModel.menuBarSpacing.resultKind)
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
        VStack(spacing: 8) {
            HStack(spacing: CGFloat(MenuBarSpacingPreference.clampedValue(value))) {
                Image(systemName: "puzzlepiece.extension")
                Image(systemName: "cloud")
                Image(systemName: "scissors")
                Image(systemName: "cup.and.saucer")
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent")
            }
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
            .padding(.horizontal, 16)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.snappy(duration: 0.2), value: value)

            Text(preference == .systemDefault
                 ? "An illustration. macOS decides the real spacing."
                 : "An illustration of \(MenuBarSpacingPreference.clampedValue(value))-point spacing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Illustration of menu bar icon spacing")
    }
}
