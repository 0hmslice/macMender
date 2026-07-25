import SwiftUI

struct ProfilesView: View {
    @ObservedObject var appModel: AppModel
    @State private var newProfileName = ""
    @State private var selectedProfileID: UUID?
    @State private var profilePendingDeletion: MacMenderProfile?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                MacMenderPageHeader(
                    title: "Profiles",
                    subtitle: "Keep separate input, window, preview, and staged Dock setups.",
                    systemImage: SettingsSection.profiles.symbolName
                )

                MacMenderCallout(systemImage: "info.circle") {
                    Text("Input, Window Switcher, Dock Preview, and staged Dock values follow the active profile. General, privacy, Safe Mode, and Menu Bar Spacing settings remain app-wide.")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: MacMenderSpacing.standard) {
                    TextField("New profile name", text: $newProfileName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(createProfile)
                        .accessibilityLabel("New profile name")

                    Button(action: createProfile) {
                        Label("Create Profile", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedNewProfileName.isEmpty)
                }

                Text("A new profile copies the active profile's setup and becomes active immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(.horizontal, MacMenderSpacing.page)
            .padding(.vertical, MacMenderSpacing.section)
            .frame(maxWidth: .infinity, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            Table(appModel.store.config.profiles, selection: $selectedProfileID) {
                TableColumn("Profile") { profile in
                    Label(profile.name, systemImage: profile.symbolName)
                        .lineLimit(1)
                }
                .width(min: 150, ideal: 190)

                TableColumn("Description") { profile in
                    Text(profile.summary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(profile.summary)
                }

                TableColumn("State") { profile in
                    if profile.id == appModel.store.config.activeProfileID {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if profile.id == MacMenderProfile.default.id {
                        Text("Default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Saved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 90, ideal: 110, max: 130)
            }
            .frame(maxWidth: 920, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .onAppear {
                selectedProfileID = appModel.store.config.activeProfileID
            }
            .onChange(of: appModel.store.config.activeProfileID) { _, profileID in
                selectedProfileID = profileID
            }

            Divider()

            profileActions
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, MacMenderSpacing.page)
                .padding(.vertical, MacMenderSpacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .confirmationDialog(
            "Delete Profile?",
            isPresented: Binding(
                get: { profilePendingDeletion != nil },
                set: { if !$0 { profilePendingDeletion = nil } }
            ),
            presenting: profilePendingDeletion
        ) { profile in
            Button("Delete \(profile.name)", role: .destructive) {
                appModel.deleteProfile(profile.id)
                selectedProfileID = appModel.store.config.activeProfileID
                profilePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                profilePendingDeletion = nil
            }
        } message: { profile in
            Text("This removes \"\(profile.name)\" and returns macMender to the remaining active setup.")
        }
    }

    private var profileActions: some View {
        HStack(spacing: MacMenderSpacing.standard) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(selectedProfile?.name ?? "Select a profile")
                    .font(.callout.weight(.medium))
                Text(selectionDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: MacMenderSpacing.standard)

            Button("Make Active") {
                guard let selectedProfileID else { return }
                appModel.setActiveProfile(selectedProfileID)
            }
            .disabled(selectedProfileID == nil || selectedProfileID == appModel.store.config.activeProfileID)

            Button("Delete Profile", role: .destructive) {
                profilePendingDeletion = selectedProfile
            }
            .foregroundStyle(.red)
            .disabled(!canDeleteSelectedProfile)
        }
    }

    private var selectedProfile: MacMenderProfile? {
        guard let selectedProfileID else { return nil }
        return appModel.store.config.profiles.first { $0.id == selectedProfileID }
    }

    private var canDeleteSelectedProfile: Bool {
        guard let selectedProfile else { return false }
        return selectedProfile.id != MacMenderProfile.default.id && appModel.store.config.profiles.count > 1
    }

    private var selectionDetail: String {
        guard let selectedProfile else {
            return "Choose a row to review or activate it."
        }
        if selectedProfile.id == appModel.store.config.activeProfileID {
            return "This profile currently drives profile-specific features."
        }
        return "Selecting a row does not activate it until you choose Make Active."
    }

    private var trimmedNewProfileName: String {
        newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createProfile() {
        guard !trimmedNewProfileName.isEmpty else { return }
        appModel.createProfile(named: newProfileName)
        selectedProfileID = appModel.store.config.activeProfileID
        newProfileName = ""
    }
}
