import SwiftUI

struct KeepAwakeView: View {
    @ObservedObject var service: KeepAwakeService
    var isPaused: Bool
    @State private var duration: KeepAwakeDuration = .oneHour
    @State private var keepDisplayAwake = false

    var body: some View {
        MacMenderScrollablePage(maxContentWidth: 760) {
            MacMenderPageHeader(
                title: "Keep Awake",
                subtitle: "Keep downloads, presentations, and long tasks running while you step away.",
                systemImage: "cup.and.saucer"
            )

            MacMenderContentSection(title: "Session", systemImage: "timer") {
                VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                    if let session = service.session {
                        HStack(spacing: 12) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title).foregroundStyle(.tint).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Mac is staying awake").font(.headline)
                                if let endsAt = session.endsAt {
                                    Text("Ends at \(endsAt.formatted(date: .omitted, time: .shortened))")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Until you stop this session").foregroundStyle(.secondary)
                                }
                                Text(session.keepsDisplayAwake ? "Display stays on" : "Display can sleep")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Stop Session", action: service.stop).buttonStyle(.bordered)
                        }
                        Divider()
                    } else {
                        Label("Normal sleep settings are active", systemImage: "moon.zzz")
                            .foregroundStyle(.secondary)
                    }

                    Picker("Duration", selection: $duration) {
                        ForEach(KeepAwakeDuration.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Toggle("Keep the display awake too", isOn: $keepDisplayAwake)
                    Button(service.isActive ? "Restart Session" : "Start Session") {
                        service.start(duration: duration, keepDisplayAwake: keepDisplayAwake)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPaused)

                    if isPaused {
                        Text("Turn off Safe Mode to start a session.").foregroundStyle(.secondary)
                    }
                    if let errorMessage = service.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }

            MacMenderCallout(systemImage: "info.circle") {
                Text("Sessions end when you quit macMender, enable Safe Mode, or put your Mac to sleep. Closing the lid still allows sleep. Sessions never restart automatically.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
