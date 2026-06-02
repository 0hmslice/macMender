import SwiftUI

enum LiquidGlassMotion {
    static let quick = Animation.easeInOut(duration: 0.16)
    static let surface = Animation.spring(response: 0.28, dampingFraction: 0.84)
    static let subtle = Animation.easeInOut(duration: 0.22)
}

enum LiquidGlassSurface {
    case windowBackground
    case sidebar
    case card
    case panel
    case row
    case button
    case preview

    var material: Material {
        switch self {
        case .windowBackground:
            .bar
        case .sidebar:
            .ultraThinMaterial
        case .card:
            .ultraThinMaterial
        case .panel, .preview:
            .regularMaterial
        case .row, .button:
            .ultraThinMaterial
        }
    }

    var radius: CGFloat {
        switch self {
        case .windowBackground, .sidebar:
            0
        case .button:
            7
        case .card, .panel, .preview, .row:
            8
        }
    }

    var strokeOpacity: Double {
        switch self {
        case .windowBackground, .sidebar:
            0
        case .button:
            0.18
        case .card, .panel, .row:
            0.14
        case .preview:
            0.28
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .windowBackground, .sidebar, .button, .row:
            0
        case .card:
            0.08
        case .panel, .preview:
            0.14
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .card:
            12
        case .panel, .preview:
            22
        case .windowBackground, .sidebar, .row, .button:
            0
        }
    }

    var highlightOpacity: Double {
        switch self {
        case .preview:
            0.26
        case .panel:
            0.16
        case .card:
            0.20
        case .row, .button:
            0.12
        case .windowBackground, .sidebar:
            0
        }
    }
}

private struct LiquidGlassSurfaceModifier: ViewModifier {
    var surface: LiquidGlassSurface
    var radius: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        let resolvedRadius = radius ?? surface.radius
        glassBase(content: content, resolvedRadius: resolvedRadius)
            .overlay(alignment: .topLeading) {
                if surface.highlightOpacity > 0 {
                    LinearGradient(
                        colors: [
                            .white.opacity(surface.highlightOpacity),
                            .white.opacity(surface.highlightOpacity * 0.25),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
            .overlay {
                if surface.strokeOpacity > 0 {
                    RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                        .stroke(.white.opacity(surface.strokeOpacity), lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(surface.shadowOpacity), radius: surface.shadowRadius, y: surface.shadowRadius > 0 ? 5 : 0)
    }

    @ViewBuilder
    private func glassBase(content: Content, resolvedRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: resolvedRadius))
        } else {
            content
                .background(surface.material, in: RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous))
        }
    }
}

extension View {
    func liquidGlass(_ surface: LiquidGlassSurface, radius: CGFloat? = nil) -> some View {
        modifier(LiquidGlassSurfaceModifier(surface: surface, radius: radius))
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(.button)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(LiquidGlassMotion.quick, value: configuration.isPressed)
    }
}

struct SoftStatusCard<Content: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tone: CapabilityBadge.Tone
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tone: CapabilityBadge.Tone = .neutral,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .liquidGlass(.card, radius: 14)
    }

    private var iconColor: Color {
        switch tone {
        case .active:
            .green
        case .warning:
            .orange
        case .neutral:
            .blue
        }
    }
}

struct FriendlyActionTile: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 38, height: 38)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .liquidGlass(.row, radius: 12)
        }
        .buttonStyle(.plain)
    }
}
