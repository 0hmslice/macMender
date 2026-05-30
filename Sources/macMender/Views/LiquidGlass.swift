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
            .thinMaterial
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
            0.14
        case .card, .panel, .row:
            0.10
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
            0.18
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
            0.18
        case .card:
            0.12
        case .row, .button:
            0.08
        case .windowBackground, .sidebar:
            0
        }
    }
}

private struct LiquidGlassSurfaceModifier: ViewModifier {
    var surface: LiquidGlassSurface
    var radius: CGFloat?

    func body(content: Content) -> some View {
        let resolvedRadius = radius ?? surface.radius
        content
            .background(surface.material, in: RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous))
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
