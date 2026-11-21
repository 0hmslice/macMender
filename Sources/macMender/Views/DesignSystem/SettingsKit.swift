import AppKit
import SwiftUI

// One layout for every settings page: a native grouped form, a page header, and a small set of
// rows. Pages compose these instead of drawing their own cards so spacing, widths, and control
// placement stay identical from page to page.

extension SettingsSection {
    /// The colour of this section's icon tile in the sidebar and page header.
    var tint: Color {
        switch self {
        case .overview: .blue
        case .dockPreviews: .indigo
        case .windowSwitcher: .purple
        case .dockSettings: .cyan
        case .input: .orange
        case .keepAwake: .brown
        case .menuBarSpacing: .teal
        case .general: .gray
        case .profiles: .pink
        case .privacy: .green
        case .advanced: Color(nsColor: .systemGray)
        }
    }
}

/// A rounded, coloured tile holding a symbol, in the style of System Settings.
struct SettingsIconTile: View {
    var systemImage: String
    var tint: Color
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.52, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.monochrome)
            }
            .accessibilityHidden(true)
    }
}

/// A settings page: a centred, width-limited grouped form that opens with the section's header.
struct SettingsPage<Content: View>: View {
    static var maximumContentWidth: CGFloat { 700 }

    var section: SettingsSection
    /// Set on pages whose settings belong to a profile, so the header can say which one.
    var profileName: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            Form {
                Section {
                    SettingsPageHeader(section: section, profileName: profileName)
                }
                content
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            // Margins, not a narrower form, so the scroll bar stays at the window's edge.
            .contentMargins(.horizontal, max(0, (proxy.size.width - Self.maximumContentWidth) / 2), for: .scrollContent)
        }
    }
}

private struct SettingsPageHeader: View {
    var section: SettingsSection
    var profileName: String?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            SettingsIconTile(systemImage: section.symbolName, tint: section.tint, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(section.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let profileName {
                    Label("Saved in the \(profileName) profile", systemImage: SettingsSection.profiles.symbolName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

/// A switch with an optional line of explanation under its title.
struct SettingsToggle: View {
    var title: String
    var detail: String? = nil
    @Binding var isOn: Bool

    init(_ title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsRowText(title: title, detail: detail)
        }
    }
}

/// A row's title with an optional smaller explanation beneath it.
struct SettingsRowText: View {
    var title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A slider with its title and current value above it, and optional captions at each end.
struct SettingsSlider: View {
    var title: String
    var detail: String? = nil
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var valueLabel: String
    var minimumLabel: String? = nil
    var maximumLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer()
                Text(valueLabel)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            HStack(spacing: 8) {
                if let minimumLabel {
                    Text(minimumLabel).font(.caption).foregroundStyle(.secondary)
                }
                // Snapping happens in the binding: a stepped slider draws a tick for every
                // step, which turns into a row of noise at fine steps.
                Slider(value: snapped, in: range)
                    .labelsHidden()
                    .accessibilityLabel(title)
                    .accessibilityValue(valueLabel)
                if let maximumLabel {
                    Text(maximumLabel).font(.caption).foregroundStyle(.secondary)
                }
            }

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private var snapped: Binding<Double> {
        Binding {
            value
        } set: { newValue in
            let stepped = (newValue / step).rounded() * step
            value = min(max(stepped, range.lowerBound), range.upperBound)
        }
    }
}

/// A row with an icon tile, a title and explanation, and a control or status on the right.
struct SettingsRow<Accessory: View>: View {
    var title: String
    var detail: String? = nil
    var systemImage: String? = nil
    var tint: Color = .gray
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let systemImage {
                SettingsIconTile(systemImage: systemImage, tint: tint, size: 26)
            }
            SettingsRowText(title: title, detail: detail)
            Spacer(minLength: 12)
            accessory
        }
        .padding(.vertical, 2)
    }
}

/// A small coloured dot and a word: "On", "Paused", "Needs access".
struct SettingsStatusBadge: View {
    var title: String
    var tone: MacMenderStatusTone

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tone == .neutral ? Color.secondary.opacity(0.6) : tone.color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

/// Explanatory text under a group, aligned with the group's leading edge.
struct SettingsFooter: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }
}

extension AppModel {
    /// A binding to one value in the active profile.
    func profileBinding<Value>(_ keyPath: WritableKeyPath<MacMenderProfile, Value>) -> Binding<Value> {
        Binding { [self] in
            activeProfile[keyPath: keyPath]
        } set: { [self] newValue in
            var profile = activeProfile
            profile[keyPath: keyPath] = newValue
            updateActiveProfile(profile)
        }
    }
}

/// The settings sidebar's backdrop, from solid to frosted glass.
///
/// macOS already draws the sidebar as frosted glass: a blur of whatever is behind the window,
/// tuned to keep the sidebar's text readable. This adds one solid layer over that frost and
/// fades it out as `amount` rises, so 0 is a solid sidebar and 1 is the system's glass.
/// The frost itself is never thinned. A clearer sidebar was tried and was unreadable over
/// ordinary windows.
struct SidebarGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var amount: Double

    static func solidOpacity(for amount: Double) -> Double {
        1 - min(max(amount, 0), 1)
    }

    var body: some View {
        SidebarBackdropInstaller(solidOpacity: reduceTransparency ? 1 : Self.solidOpacity(for: amount))
            .allowsHitTesting(false)
    }
}

/// Places the solid layer at the very bottom of the view that hosts the sidebar.
///
/// It cannot simply be a SwiftUI background: the sidebar's content is drawn above the window's
/// close, minimize, and zoom buttons, so anything opaque there would cover them. The split view
/// hosts the sidebar inside its own frosted view, and the layer goes in as that host's first
/// subview, under the buttons. If a future macOS arranges the sidebar differently, no host is
/// found and the sidebar keeps the system's standard look.
private struct SidebarBackdropInstaller: NSViewRepresentable {
    var solidOpacity: Double

    func makeNSView(context: Context) -> InstallerView {
        InstallerView()
    }

    func updateNSView(_ nsView: InstallerView, context: Context) {
        nsView.solidOpacity = solidOpacity
        nsView.apply()
    }

    final class InstallerView: NSView {
        var solidOpacity = 0.0
        private weak var solid: NSBox?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            // The host is only in place once the split view has finished building.
            DispatchQueue.main.async { [weak self] in self?.install() }
        }

        private func install() {
            guard solid == nil, let host = hostingEffectView() else { return }
            let box = NonInteractiveBox(frame: host.bounds)
            box.boxType = .custom
            box.borderWidth = 0
            box.fillColor = .windowBackgroundColor
            box.autoresizingMask = [.width, .height]
            host.addSubview(box, positioned: .below, relativeTo: host.subviews.first)
            solid = box
            apply()
        }

        func apply() {
            solid?.alphaValue = solidOpacity
        }

        private func hostingEffectView() -> NSVisualEffectView? {
            var ancestor = superview
            var depth = 0
            while let current = ancestor, depth < 20, !(current is NSSplitView) {
                if let host = current as? NSVisualEffectView { return host }
                ancestor = current.superview
                depth += 1
            }
            return nil
        }
    }
}

private final class NonInteractiveBox: NSBox {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
