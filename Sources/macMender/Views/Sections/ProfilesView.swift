import SwiftUI

struct ProfilesView: View {
    @ObservedObject var appModel: AppModel
    @State private var newProfileName = ""
    @State private var profilePendingDeletion: MacMenderProfile?

    var body: some View {
        PreferencesScrollView {
            SectionCard(
                title: "Default Settings",
                subtitle: "macMender starts with one balanced default. Create extra profiles only if you want separate setups.",
                symbolName: "wrench.and.screwdriver"
            ) {
                HStack(spacing: 12) {
                    Image(systemName: appModel.activeProfile.symbolName)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(appModel.activeProfile.name)
                            .font(.headline)
                        Text(appModel.activeProfile.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    CapabilityBadge(title: "Active", systemImage: "checkmark.circle.fill", tone: .active)
                }
            }

            SectionCard(
                title: "Create Another Profile",
                subtitle: "Optional. New profiles copy the current settings so you can adjust them separately.",
                symbolName: "plus.rectangle.on.rectangle"
            ) {
                HStack(spacing: 14) {
                    if appModel.store.config.profiles.count == 1 {
                        MendyAvatarView(mood: .sleeping, size: MendyAvatarSize.compact)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if appModel.store.config.profiles.count == 1 {
                            Text("You only have the default setup. Mendy can create another one when you need a separate context.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            TextField("Profile name", text: $newProfileName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 320)

                            Button("Create Profile") {
                                appModel.createProfile(named: newProfileName)
                                newProfileName = ""
                            }
                            .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }

            if appModel.store.config.profiles.count > 1 {
                SectionCard(
                    title: "Custom Profiles",
                    subtitle: "Switch between only the profiles you created.",
                    symbolName: "square.stack.3d.up"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(appModel.store.config.profiles) { profile in
                            HStack(spacing: 12) {
                                Image(systemName: profile.symbolName)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.name)
                                    Text(profile.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if profile.id == appModel.store.config.activeProfileID {
                                    CapabilityBadge(title: "Active", systemImage: "checkmark.circle.fill", tone: .active)
                                } else {
                                    Button("Switch") {
                                        appModel.setActiveProfile(profile.id)
                                    }
                                }
                                if profile.id != MacMenderProfile.default.id {
                                    Button("Delete", role: .destructive) {
                                        profilePendingDeletion = profile
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
            }

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
            Text("This removes \"\(profile.name)\" and returns macMender to the remaining active setup.")
        }
    }
}
