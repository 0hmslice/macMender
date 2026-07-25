import SwiftUI

struct ProfilesView: View {
    @ObservedObject var appModel: AppModel
    @State private var newProfileName = ""
    @State private var isCreatingProfile = false
    @State private var selectedProfileID: UUID?
    @State private var profilePendingDeletion: MacMenderProfile?

    var body: some View {
        MacMenderScrollablePage(maxContentWidth: 860) {
            MacMenderPageHeader(
                title: "Profiles",
                subtitle: "Keep separate input, window, preview, and staged Dock setups.",
                systemImage: SettingsSection.profiles.symbolName
            )

            MacMenderCallout(systemImage: "info.circle") {
                Text("Input, Window Switcher, Dock Preview, and staged Dock values follow the active profile. General, privacy, Safe Mode, and Menu Bar Spacing settings remain app-wide.")
                    .foregroundStyle(.secondary)
            }

            MacMenderContentSection(
                title: "Saved Setups",
                subtitle: "Select a profile to review it. Changing the active profile updates profile-specific features.",
                systemImage: "square.stack.3d.up"
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(appModel.store.config.profiles.enumerated()), id: \.element.id) { index, profile in
                        profileRow(profile)

                        if index < appModel.store.config.profiles.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }

                Divider()

                HStack(spacing: MacMenderSpacing.standard) {
                    Text("A new profile starts as a copy of the current setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: MacMenderSpacing.standard)

                    Button {
                        newProfileName = ""
                        isCreatingProfile = true
                    } label: {
                        Label("New Profile", systemImage: "plus")
                    }
                }
            }

            MacMenderContentSection(
                title: selectedProfile?.name ?? "No Profile Selected",
                subtitle: selectionDetail,
                systemImage: selectedProfile?.symbolName ?? "square.dashed"
            ) {
                HStack(spacing: MacMenderSpacing.standard) {
                    Text(profileStateTitle(selectedProfile))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: MacMenderSpacing.standard)

                    Button("Make Active") {
                        guard let selectedProfileID else { return }
                        appModel.setActiveProfile(selectedProfileID)
                    }
                    .disabled(selectedProfileID == nil || selectedProfileID == appModel.store.config.activeProfileID)

                    Button("Delete Profile", role: .destructive) {
                        profilePendingDeletion = selectedProfile
                    }
                    .disabled(!canDeleteSelectedProfile)
                }
            }
        }
        .onAppear(perform: synchronizeSelection)
        .onChange(of: appModel.store.config.activeProfileID) { _, profileID in
            selectedProfileID = profileID
        }
        .sheet(isPresented: $isCreatingProfile) {
            NewProfileSheet(
                name: $newProfileName,
                onCancel: { isCreatingProfile = false },
                onCreate: createProfile
            )
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

    private func profileRow(_ profile: MacMenderProfile) -> some View {
        Button {
            selectedProfileID = profile.id
        } label: {
            HStack(spacing: MacMenderSpacing.standard) {
                Image(systemName: profile.symbolName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                    Text(profile.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(profile.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: MacMenderSpacing.standard)

                if profile.id == appModel.store.config.activeProfileID {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: selectedProfileID == profile.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedProfileID == profile.id ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, MacMenderSpacing.small)
            .padding(.vertical, MacMenderSpacing.standard)
            .contentShape(.rect)
            .background(
                Color.accentColor.opacity(selectedProfileID == profile.id ? 0.10 : 0),
                in: RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(profile.name), \(profileStateTitle(profile))")
        .accessibilityHint("Select profile")
        .accessibilityAddTraits(selectedProfileID == profile.id ? .isSelected : [])
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
            return "Choose a saved setup to review it."
        }
        if selectedProfile.id == appModel.store.config.activeProfileID {
            return "This profile currently controls profile-specific features."
        }
        return "Make this profile active to use its saved feature settings."
    }

    private func profileStateTitle(_ profile: MacMenderProfile?) -> String {
        guard let profile else { return "Nothing selected" }
        if profile.id == appModel.store.config.activeProfileID { return "Current profile" }
        if profile.id == MacMenderProfile.default.id { return "Default profile" }
        return "Saved profile"
    }

    private var trimmedNewProfileName: String {
        newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func synchronizeSelection() {
        let profiles = appModel.store.config.profiles
        if let selectedProfileID, profiles.contains(where: { $0.id == selectedProfileID }) {
            return
        }
        self.selectedProfileID = appModel.store.config.activeProfileID
    }

    private func createProfile() {
        guard !trimmedNewProfileName.isEmpty else { return }
        appModel.createProfile(named: newProfileName)
        selectedProfileID = appModel.store.config.activeProfileID
        newProfileName = ""
        isCreatingProfile = false
    }
}

private struct NewProfileSheet: View {
    @Binding var name: String
    var onCancel: () -> Void
    var onCreate: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text("New Profile")
                    .font(.title2.weight(.semibold))
                Text("Give this copy of your current setup a short, recognizable name.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("Profile name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)
                .onSubmit(createIfPossible)
                .accessibilityLabel("Profile name")

            HStack(spacing: MacMenderSpacing.compact) {
                Spacer()

                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Create Profile", action: createIfPossible)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(MacMenderSpacing.page)
        .frame(width: 420)
        .onAppear { isNameFocused = true }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createIfPossible() {
        guard !trimmedName.isEmpty else { return }
        onCreate()
    }
}
