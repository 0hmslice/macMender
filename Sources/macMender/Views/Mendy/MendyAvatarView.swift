import AppKit
import SwiftUI

enum MendyMood: String, CaseIterable {
    case greeting
    case happy
    case thinking
    case scanning
    case idle
    case sleeping
    case success
    case error

    var accessibilityLabel: String {
        switch self {
        case .greeting: "Mendy says hello"
        case .happy: "Mendy is happy"
        case .thinking: "Mendy is thinking"
        case .scanning: "Mendy is scanning"
        case .idle: "Mendy is ready"
        case .sleeping: "Mendy is waiting"
        case .success: "Mendy says everything looks good"
        case .error: "Mendy needs attention"
        }
    }

    var assetName: String {
        switch self {
        case .greeting: MendyAssets.greeting
        case .happy: MendyAssets.happy
        case .thinking: MendyAssets.thinking
        case .scanning: MendyAssets.scanning
        case .idle: MendyAssets.idleState
        case .sleeping: MendyAssets.sleeping
        case .success: MendyAssets.success
        case .error: MendyAssets.error
        }
    }

    var accentColor: Color {
        switch self {
        case .greeting: .teal
        case .happy: .green
        case .thinking: .indigo
        case .scanning: .blue
        case .idle: .cyan
        case .sleeping: .secondary
        case .success: .green
        case .error: .orange
        }
    }
}

enum MendyAssets {
    static let appIcon = "MendyAppIcon"
    static let avatar = "MendyRobotHead"
    static let head = "MendyRobotHead"
    static let menuBarColor = "MendyMenuBarIcon"
    static let menuBarTemplate = "MendyStatusItem"
    static let greeting = "MendyGreeting"
    static let happy = "MendyHappy"
    static let thinking = "MendyThinking"
    static let scanning = "MendyScanning"
    static let idleState = "MendyIdleState"
    static let sleeping = "MendySleeping"
    static let success = "MendySuccess"
    static let error = "MendyError"

    static let stateAssetNames = [
        greeting,
        happy,
        thinking,
        scanning,
        idleState,
        sleeping,
        success,
        error
    ]

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

enum MendyAvatarSize {
    static let hero: CGFloat = 180
    static let prominent: CGFloat = 128
    static let panel: CGFloat = 108
    static let compact: CGFloat = 84
    static let sidebar: CGFloat = 76
}

struct MendyAvatarView: View {
    let mood: MendyMood
    let size: CGFloat
    var showsGlass: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            ambientGlow
            glassBackground

            Image(nsImage: currentImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(size * 0.025)
                .scaleEffect(imageFillScale)
                .scaleEffect(activityScale)
                .offset(x: activityOffset.width, y: activityOffset.height)
                .rotationEffect(activityRotation)
                .shadow(color: mood.accentColor.opacity(activityGlow), radius: size * 0.16, y: size * 0.04)
                .id(mood.assetName)
                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.985)))
                .animation(activityAnimation, value: isAnimating)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mood.accessibilityLabel)
        .onAppear {
            restartAnimation()
        }
        .onChange(of: mood) { _, _ in
            restartAnimation()
        }
        .onChange(of: scenePhase) { _, _ in
            restartAnimation()
        }
    }

    private var currentImage: NSImage {
        MendyAssets.image(named: mood.assetName) ??
            MendyAssets.image(named: MendyAssets.avatar) ??
            NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    private func restartAnimation() {
        isAnimating = false
        DispatchQueue.main.async {
            withAnimation(activityAnimation) {
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
                .shadow(color: mood.accentColor.opacity(glowOpacity), radius: size * 0.2, y: size * 0.05)
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

    private var ambientGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        mood.accentColor.opacity(reduceMotion ? 0.14 : glowOpacity),
                        mood.accentColor.opacity(0.08),
                        .clear
                    ],
                    center: .center,
                    startRadius: size * 0.12,
                    endRadius: size * 0.62
                )
            )
            .frame(width: size * 1.16, height: size * 1.16)
            .scaleEffect(isAnimating && mood.isLively && !reduceMotion ? 1.04 : 0.98)
            .blur(radius: size * 0.035)
            .allowsHitTesting(false)
    }

    private var activityScale: CGFloat {
        guard mood.isLively, permitsContinuousMotion else { return 1 }
        switch mood {
        case .success:
            return isAnimating ? 1.1 : 0.955
        case .error:
            return 1
        case .scanning:
            return isAnimating ? 1.045 : 0.975
        case .thinking, .idle, .greeting, .happy:
            return isAnimating ? 1.032 : 0.988
        case .sleeping:
            return isAnimating ? 1.006 : 0.994
        }
    }

    private var imageFillScale: CGFloat {
        switch mood {
        case .greeting, .happy, .success:
            1.08
        case .thinking, .scanning:
            1.06
        case .idle, .sleeping, .error:
            1.04
        }
    }

    private var activityOffset: CGSize {
        guard mood.isLively, permitsContinuousMotion else { return .zero }
        switch mood {
        case .idle, .greeting, .happy, .sleeping:
            return CGSize(width: 0, height: isAnimating ? -size * 0.035 : size * 0.014)
        case .thinking:
            return CGSize(width: 0, height: isAnimating ? -size * 0.026 : 0)
        case .scanning, .success:
            return .zero
        case .error:
            return CGSize(width: isAnimating ? size * 0.032 : -size * 0.032, height: 0)
        }
    }

    private var activityRotation: Angle {
        guard mood == .error, permitsContinuousMotion else { return .zero }
        return isAnimating ? .degrees(2.4) : .degrees(-2.4)
    }

    private var activityGlow: Double {
        guard mood.isLively else { return 0.2 }
        return isAnimating ? 0.34 : 0.18
    }

    private var activityAnimation: Animation? {
        guard mood.isLively, permitsContinuousMotion else { return nil }
        switch mood {
        case .success:
            return .spring(response: 0.32, dampingFraction: 0.52)
        case .error:
            return .linear(duration: 0.08).repeatCount(5, autoreverses: true)
        case .scanning:
            return .easeInOut(duration: mood.animationDuration).repeatForever(autoreverses: true)
        case .thinking, .idle, .greeting, .happy, .sleeping:
            return .easeInOut(duration: mood.animationDuration).repeatForever(autoreverses: true)
        }
    }

    private var glowOpacity: Double {
        switch mood {
        case .scanning, .thinking:
            isAnimating ? 0.32 : 0.16
        case .error:
            0.28
        case .success, .happy:
            0.22
        case .greeting, .idle, .sleeping:
            0.14
        }
    }

    private var permitsContinuousMotion: Bool {
        !reduceMotion && scenePhase == .active && showsGlass && size >= MendyAvatarSize.panel
    }
}

private extension MendyMood {
    var isLively: Bool {
        switch self {
        case .greeting, .happy, .thinking, .scanning, .idle, .sleeping, .success, .error:
            true
        }
    }

    var animationDuration: Double {
        switch self {
        case .greeting: 2.4
        case .happy: 2.0
        case .thinking: 1.7
        case .scanning: 1.15
        case .idle: 3.2
        case .sleeping: 3.8
        case .success: 0.32
        case .error: 0.08
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
