import SwiftUI

struct PreferencesScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .liquidGlass(.windowBackground)
    }
}

struct SectionCard<Content: View>: View {
    var title: String
    var subtitle: String?
    var symbolName: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.card)
    }
}

struct CapabilityBadge: View {
    var title: String
    var systemImage: String
    var tone: Tone

    enum Tone {
        case active
        case warning
        case neutral
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
            .overlay {
                Capsule()
                    .stroke(foreground.opacity(0.16), lineWidth: 1)
            }
    }

    private var background: Color {
        switch tone {
        case .active: .green.opacity(0.16)
        case .warning: .orange.opacity(0.18)
        case .neutral: .secondary.opacity(0.12)
        }
    }

    private var foreground: Color {
        switch tone {
        case .active: .green
        case .warning: .orange
        case .neutral: .secondary
        }
    }
}

struct LabeledSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var valueLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueLabel)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct EmptyStateView: View {
    var title: String
    var message: String
    var symbolName: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.78))
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .liquidGlass(.panel)
    }
}
