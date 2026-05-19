import AppKit
import SwiftUI

enum MendyMood: String, CaseIterable {
    case idle
    case fixing
    case profileChange
    case alert
    case success
    case empty

    var accessibilityLabel: String {
        switch self {
        case .idle: "Mendy is ready"
        case .fixing: "Mendy is applying changes"
        case .profileChange: "Mendy is organizing settings"
        case .alert: "Mendy needs attention"
        case .success: "Mendy says everything looks good"
        case .empty: "Mendy is waiting for items"
        }
    }

    var badgeSymbol: String? {
        switch self {
        case .idle: nil
        case .fixing: "gearshape.fill"
        case .profileChange: "rectangle.3.group.fill"
        case .alert: "exclamationmark.triangle.fill"
        case .success: "checkmark.circle.fill"
        case .empty: "plus"
        }
    }

    var accentColor: Color {
        switch self {
        case .idle: .cyan
        case .fixing: .blue
        case .profileChange: .purple
        case .alert: .orange
        case .success: .green
        case .empty: .secondary
        }
    }
}

enum MendyAssets {
    static let appIcon = "MendyAppIcon"
    static let avatar = "MendyRobotHead"
    static let head = "MendyRobotHead"
    static let menuBarColor = "MendyMenuBarIcon"
    static let menuBarTemplate = "MendyMenuBarTemplate"

    static func image(named name: String) -> NSImage? {
        if let image = NSImage(named: name) {
            return image
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Mendy") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Mendy") {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    static var menuBarImage: NSImage {
        let image = image(named: menuBarTemplate) ?? image(named: menuBarColor) ?? image(named: head) ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        image.isTemplate = true
        image.size = NSSize(width: 22, height: 18)
        return image
    }
}

struct MendyAvatarView: View {
    let mood: MendyMood
    let size: CGFloat
    var showsGlass: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            glassBackground

            Image(nsImage: MendyAssets.image(named: MendyAssets.avatar) ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(size * 0.07)
                .scaleEffect(activityScale)
                .shadow(color: mood.accentColor.opacity(activityGlow), radius: size * 0.13, y: size * 0.04)
                .animation(activityAnimation, value: isAnimating)

            if let badgeSymbol = mood.badgeSymbol {
                moodBadge(symbol: badgeSymbol)
                    .offset(x: size * 0.01, y: size * 0.01)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mood.accessibilityLabel)
        .onAppear {
            isAnimating = true
        }
        .onChange(of: mood) { _, _ in
            isAnimating = false
            DispatchQueue.main.async {
                isAnimating = true
            }
        }
    }

    @ViewBuilder
    private var glassBackground: some View {
        if showsGlass {
            RoundedRectangle(cornerRadius: max(8, size * 0.22), style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: max(8, size * 0.22), style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: mood.accentColor.opacity(glowOpacity), radius: size * 0.18, y: size * 0.05)
                .overlay {
                    if mood.isLively {
                        RoundedRectangle(cornerRadius: max(8, size * 0.22), style: .continuous)
                            .stroke(mood.accentColor.opacity(isAnimating ? 0.38 : 0.12), lineWidth: 1.2)
                            .scaleEffect(isAnimating && !reduceMotion ? 1.035 : 1)
                            .animation(activityAnimation, value: isAnimating)
                    }
                }
        }
    }

    private var activityScale: CGFloat {
        guard mood.isLively, !reduceMotion else { return 1 }
        return isAnimating ? 1.015 : 0.99
    }

    private var activityGlow: Double {
        guard mood.isLively else { return 0.2 }
        return isAnimating ? 0.34 : 0.18
    }

    private var activityAnimation: Animation? {
        guard mood.isLively, !reduceMotion else { return nil }
        return .easeInOut(duration: mood.animationDuration).repeatForever(autoreverses: true)
    }

    private var glowOpacity: Double {
        switch mood {
        case .fixing, .profileChange:
            isAnimating ? 0.38 : 0.18
        case .alert:
            0.28
        case .success:
            0.22
        case .idle, .empty:
            0.14
        }
    }

    private func moodBadge(symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
            Circle()
                .fill(mood.accentColor.opacity(0.18))
            Image(systemName: symbol)
                .font(.system(size: max(9, size * 0.14), weight: .bold))
                .foregroundStyle(mood.accentColor)
                .rotationEffect(mood == .fixing && isAnimating ? .degrees(360) : .zero)
                .animation(
                    mood == .fixing && !reduceMotion
                        ? .linear(duration: 5).repeatForever(autoreverses: false)
                        : .snappy(duration: 0.2),
                    value: isAnimating
                )
        }
        .frame(width: size * 0.32, height: size * 0.32)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
    }
}

private extension MendyMood {
    var isLively: Bool {
        switch self {
        case .fixing, .profileChange:
            true
        case .idle, .alert, .success, .empty:
            false
        }
    }

    var animationDuration: Double {
        switch self {
        case .fixing: 1.4
        case .profileChange: 1.8
        case .idle, .alert, .success, .empty: 2.4
        }
    }
}

struct MendyMenuBarIconView: View {
    var body: some View {
        Image(nsImage: MendyAssets.menuBarImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 22, height: 18)
            .accessibilityLabel("macMender")
    }
}
