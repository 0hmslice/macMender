import AppKit
import SwiftUI

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

struct DeviceRuleRow: View {
    var rule: DeviceScrollRule
    var smoothing: Binding<Bool>
    var reverseVertical: Binding<Bool>
    var reverseHorizontal: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            HStack(spacing: MacMenderSpacing.standard) {
                Image(systemName: rule.deviceKind == .builtInTrackpad ? "rectangle.and.hand.point.up.left" : "computermouse")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                    Text(rule.displayName)
                        .font(.body.weight(.medium))
                    if rule.displayName != rule.deviceKind.title {
                        Text(rule.deviceKind.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if rule.isPhysicalDeviceSpecific {
                    MacMenderStatusLabel(title: "Device-specific", tone: .neutral, systemImage: "sensor")
                }
            }

            HStack(spacing: MacMenderSpacing.section) {
                Toggle("Smooth", isOn: smoothing)
                    .accessibilityLabel("Smooth scrolling for \(rule.displayName)")
                Toggle("Reverse Vertical", isOn: reverseVertical)
                    .accessibilityLabel("Reverse vertical scrolling for \(rule.displayName)")
                Toggle("Reverse Horizontal", isOn: reverseHorizontal)
                    .accessibilityLabel("Reverse horizontal scrolling for \(rule.displayName)")
            }
        }
        .padding(.vertical, MacMenderSpacing.standard)
    }
}

struct AppOverrideRow: View {
    @State private var appIcon: NSImage?

    var rule: AppScrollRule
    var smoothing: Binding<Bool?>
    var reverseVertical: Binding<Bool?>
    var reverseHorizontal: Binding<Bool?>
    var deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            HStack(spacing: MacMenderSpacing.standard) {
                Group {
                    if let appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                    } else {
                        Image(systemName: "app")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                }
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                    Text(rule.appName)
                        .font(.body.weight(.medium))
                    Text(rule.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Button("Remove", role: .destructive, action: deleteAction)
                    .accessibilityLabel("Remove scroll override for \(rule.appName)")
            }

            HStack(spacing: MacMenderSpacing.standard) {
                TriStateOverridePicker(
                    title: "Smoothing",
                    accessibilityLabel: "Smoothing override for \(rule.appName)",
                    value: smoothing
                )
                TriStateOverridePicker(
                    title: "Reverse Vertical",
                    accessibilityLabel: "Reverse vertical scrolling override for \(rule.appName)",
                    value: reverseVertical
                )
                TriStateOverridePicker(
                    title: "Reverse Horizontal",
                    accessibilityLabel: "Reverse horizontal scrolling override for \(rule.appName)",
                    value: reverseHorizontal
                )
            }
        }
        .padding(.vertical, MacMenderSpacing.standard)
        .task(id: rule.bundleIdentifier) {
            appIcon = resolveIcon()
        }
    }

    private func resolveIcon() -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleIdentifier) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

private struct TriStateOverridePicker: View {
    var title: String
    var accessibilityLabel: String
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
        .pickerStyle(.menu)
        .frame(minWidth: 150)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(OverrideValue(value.wrappedValue).title)
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
            "Inherit"
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
        VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
            Text("Response Preview")
                .font(.subheadline.weight(.medium))

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.72))
                        .frame(width: 14, height: max(4, min(72, abs(sample.y))))
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 82, alignment: .bottom)

            Text("A taller early response feels more immediate; a longer tail feels smoother.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(MacMenderSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macMenderContentSurface(radius: MacMenderRadius.control)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scroll response preview")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Taller early bars mean a more immediate response; a longer tail means smoother scrolling.")
    }
}
