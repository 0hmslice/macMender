import SwiftUI

struct ProfilesView: View {
    @ObservedObject var appModel: AppModel
    @State private var newProfileName = ""
    @State private var isCreatingProfile = false
    @State private var profilePendingDeletion: MacMenderProfile?

    var body: some View {
        SettingsPage(section: .profiles) {
            Section {
                ForEach(appModel.store.config.profiles) { profile in
                    profileRow(profile)
                }
                HStack {
                    Spacer()
                    Button {
                        newProfileName = ""
                        isCreatingProfile = true
                    } label: {
                        Label("New Profile…", systemImage: "plus")
                    }
                }
            } header: {
                Text("Your Profiles")
            } footer: {
                SettingsFooter("A profile holds Dock Previews, Window Switcher, Dock, and Mouse & Trackpad settings. A new profile starts as a copy of the one in use. General, Menu Bar Spacing, and Privacy are the same in every profile.")
            }
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
                profilePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                profilePendingDeletion = nil
            }
        } message: { profile in
            Text("\"\(profile.name)\" and its settings will be removed. This cannot be undone.")
        }
    }

    private func profileRow(_ profile: MacMenderProfile) -> some View {
        let isActive = profile.id == appModel.store.config.activeProfileID
        let canDelete = profile.id != MacMenderProfile.default.id && appModel.store.config.profiles.count > 1

        return SettingsRow(
            title: profile.name,
            detail: profile.summary,
            systemImage: profile.symbolName,
            tint: isActive ? SettingsSection.profiles.tint : .gray
        ) {
            if isActive {
                Label("In Use", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                Button("Use") { appModel.setActiveProfile(profile.id) }
            }
            if canDelete {
                Button(role: .destructive) {
                    profilePendingDeletion = profile
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete this profile")
                .accessibilityLabel("Delete \(profile.name)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var trimmedNewProfileName: String {
        newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createProfile() {
        guard !trimmedNewProfileName.isEmpty else { return }
        appModel.createProfile(named: newProfileName)
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
