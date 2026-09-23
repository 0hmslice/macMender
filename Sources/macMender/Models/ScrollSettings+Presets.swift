import Foundation

extension ScrollSettings {
    /// Presets change the response, preserving direction and all personal rules.
    mutating func applyPreset(_ preset: SmoothingPreset) {
        let response: ScrollSettings
        switch preset {
        case .off: response = .raw
        case .subtle: response = .subtle
        case .balanced: response = .balanced
        case .smooth:
            var smooth = Self.balanced
            smooth.step = 1.25
            smooth.gain = 1.35
            smooth.duration = 0.24
            response = smooth
        case .custom:
            self.preset = .custom
            return
        }
        self.preset = preset
        verticalSmoothingEnabled = response.verticalSmoothingEnabled
        horizontalSmoothingEnabled = response.horizontalSmoothingEnabled
        step = response.step
        gain = response.gain
        duration = response.duration
    }

    mutating func normalize() {
        step = step.isFinite ? min(6, max(0.25, step)) : 1
        gain = gain.isFinite ? min(3, max(0.5, gain)) : 1
        duration = duration.isFinite ? min(0.5, max(0, duration)) : 0
        var seen = Set<String>()
        appRules = appRules.filter { !$0.bundleIdentifier.isEmpty && seen.insert($0.bundleIdentifier).inserted }
    }
}
