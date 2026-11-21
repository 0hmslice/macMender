import SwiftUI

struct KeepAwakeView: View {
    @ObservedObject var service: KeepAwakeService
    var isPaused: Bool
    @State private var duration: KeepAwakeDuration = .oneHour
    @State private var keepDisplayAwake = false

    var body: some View {
        SettingsPage(section: .keepAwake) {
            if let session = service.session {
                Section {
                    SettingsRow(
                        title: "Your Mac is staying awake",
                        detail: sessionDetail(session),
                        systemImage: "cup.and.saucer.fill",
                        tint: SettingsSection.keepAwake.tint
                    ) {
                        Button("Stop", action: service.stop)
                    }
                }
            }

            Section {
                Picker("Stay awake for", selection: $duration) {
                    ForEach(KeepAwakeDuration.allCases) { Text($0.title).tag($0) }
                }
                SettingsToggle(
                    "Keep the display on",
                    detail: "When off, the screen can still sleep while the Mac keeps working.",
                    isOn: $keepDisplayAwake
                )
                HStack {
                    if isPaused {
                        Text("macMender is paused. Resume it to start a session.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(service.isActive ? "Restart with These Settings" : "Start") {
                        service.start(duration: duration, keepDisplayAwake: keepDisplayAwake)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPaused)
                }

                if let errorMessage = service.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            } header: {
                Text(service.isActive ? "Change Session" : "New Session")
            } footer: {
                SettingsFooter("A session ends when its time is up, when the Mac sleeps, or when you pause or quit macMender. Closing the lid still puts the Mac to sleep.")
            }
            .disabled(isPaused)
        }
        .onAppear {
            // Show the running session's choices instead of the defaults.
            if let session = service.session {
                keepDisplayAwake = session.keepsDisplayAwake
            }
        }
    }

    private func sessionDetail(_ session: KeepAwakeSession) -> String {
        let end = session.endsAt.map { "Until \($0.formatted(date: .omitted, time: .shortened))" } ?? "Until you stop it"
        return "\(end) · \(session.keepsDisplayAwake ? "display stays on" : "display can sleep")"
    }
}
