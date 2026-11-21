import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RunningAppOption: Identifiable {
    var id: String { bundleIdentifier }
    var bundleIdentifier: String
    var name: String
}

extension Array where Element == RunningAppOption {
    func uniquedByBundleIdentifier() -> [RunningAppOption] {
        var seen = Set<String>()
        return filter { option in
            guard !seen.contains(option.bundleIdentifier) else { return false }
            seen.insert(option.bundleIdentifier)
            return true
        }
    }
}

/// A menu that adds an application: any running app, or one chosen from disk.
struct AddApplicationMenu: View {
    var title = "Add App"
    var candidates: [RunningAppOption]
    var onOpen: () -> Void = {}
    var onAdd: (_ bundleIdentifier: String, _ name: String) -> Void

    var body: some View {
        Menu {
            ForEach(candidates) { candidate in
                Button(candidate.name) { onAdd(candidate.bundleIdentifier, candidate.name) }
            }
            if !candidates.isEmpty { Divider() }
            Button("Choose from Applications…", action: chooseApplication)
        } label: {
            Label(title, systemImage: "plus")
        }
        .fixedSize()
        .onAppear(perform: onOpen)
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an App"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else { return }
            onAdd(bundleIdentifier, url.deletingPathExtension().lastPathComponent)
        }
    }
}

/// An application's icon, looked up by bundle identifier.
struct ApplicationIcon: View {
    var bundleIdentifier: String
    var size: CGFloat = 24
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
            }
        }
        .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: bundleIdentifier) {
            icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
        }
    }
}

struct AppOverrideRow: View {
    var rule: AppScrollRule
    var bypass: Binding<Bool>
    var smoothing: Binding<Bool?>
    var reverseVertical: Binding<Bool?>
    var reverseHorizontal: Binding<Bool?>
    var deleteAction: () -> Void

    var body: some View {
        DisclosureGroup {
            Toggle("Scroll the way macOS does", isOn: bypass)
                .help("macMender leaves this app's scrolling completely alone.")
            Group {
                TriStateOverridePicker(title: "Smoothing", value: smoothing)
                TriStateOverridePicker(title: "Reverse vertical", value: reverseVertical)
                TriStateOverridePicker(title: "Reverse horizontal", value: reverseHorizontal)
            }
            .disabled(bypass.wrappedValue)
        } label: {
            HStack(spacing: 10) {
                ApplicationIcon(bundleIdentifier: rule.bundleIdentifier)
                SettingsRowText(title: rule.appName, detail: summary)
                Spacer()
                Button(role: .destructive, action: deleteAction) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove this exception")
                .accessibilityLabel("Remove exception for \(rule.appName)")
            }
        }
    }

    private var summary: String {
        if bypass.wrappedValue { return "Scrolls the way macOS does" }
        var parts: [String] = []
        if let value = smoothing.wrappedValue { parts.append(value ? "Smoothing on" : "Smoothing off") }
        if let value = reverseVertical.wrappedValue { parts.append(value ? "Vertical reversed" : "Vertical not reversed") }
        if let value = reverseHorizontal.wrappedValue { parts.append(value ? "Horizontal reversed" : "Horizontal not reversed") }
        return parts.isEmpty ? "Same as other apps" : parts.joined(separator: " · ")
    }
}

private struct TriStateOverridePicker: View {
    var title: String
    var value: Binding<Bool?>

    var body: some View {
        Picker(title, selection: Binding(
            get: { OverrideValue(value.wrappedValue) },
            set: { value.wrappedValue = $0.boolValue }
        )) {
            ForEach(OverrideValue.allCases) { option in
                Text(option.title).tag(option)
            }
        }
    }
}

private enum OverrideValue: String, CaseIterable, Identifiable {
    case inherit
    case on
    case off

    init(_ value: Bool?) {
        switch value {
        case true:
            self = .on
        case false:
            self = .off
        case nil:
            self = .inherit
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inherit:
            "Same as other apps"
        case .on:
            "On"
        case .off:
            "Off"
        }
    }

    var boolValue: Bool? {
        switch self {
        case .inherit:
            nil
        case .on:
            true
        case .off:
            false
        }
    }
}

struct ScrollPreview: View {
    var settings: ScrollSettings

    private var samples: [ScrollSample] {
        ScrollTransformer(settings: settings).projectedSamples(
            from: ScrollSample(x: 0, y: 120),
            count: 10
        )
    }

    private var accessibilityValue: String {
        let smoothing = settings.verticalSmoothingEnabled ? "Vertical smoothing on" : "Vertical smoothing off"
        let response = settings.duration > 0
            ? "response tapers over \(settings.duration.sliderValueLabel) seconds"
            : "response is immediate with no smoothing tail"

        return "\(settings.preset.title) preset. \(smoothing). Gain \(settings.gain.sliderValueLabel); \(response)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.75))
                        .frame(width: 14, height: max(4, min(56, abs(sample.y))))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .bottomLeading)
            .animation(.snappy(duration: 0.2), value: samples.map(\.y))

            Text("One turn of the wheel over time. A tall start feels immediate; a long tail feels smooth.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scroll response preview")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Taller early bars mean a more immediate response; a longer tail means smoother scrolling.")
    }
}
