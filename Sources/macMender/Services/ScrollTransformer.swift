import Foundation

struct ScrollSample: Equatable {
    var x: Double
    var y: Double
}

struct ScrollTransformer {
    var settings: ScrollSettings

    func transform(_ sample: ScrollSample, deviceRule: DeviceScrollRule? = nil, appRule: AppScrollRule? = nil) -> ScrollSample {
        guard appRule?.bypassScrolling != true else { return sample }
        let reverseVertical = appRule?.reverseVerticalOverride ?? deviceRule?.reverseVertical ?? settings.reverseVertical
        let reverseHorizontal = appRule?.reverseHorizontalOverride ?? deviceRule?.reverseHorizontal ?? settings.reverseHorizontal

        let verticalGain = smoothsVertical(deviceRule: deviceRule, appRule: appRule) ? settings.gain : 1
        let horizontalGain = smoothsHorizontal(deviceRule: deviceRule, appRule: appRule) ? settings.gain : 1
        let yDirection = reverseVertical ? -1.0 : 1.0
        let xDirection = reverseHorizontal ? -1.0 : 1.0

        return ScrollSample(
            x: sample.x * horizontalGain * xDirection,
            y: sample.y * verticalGain * yDirection
        )
    }

    func smoothsVertical(deviceRule: DeviceScrollRule? = nil, appRule: AppScrollRule? = nil) -> Bool {
        appRule?.bypassScrolling != true &&
            (appRule?.smoothingOverride ?? (settings.verticalSmoothingEnabled && (deviceRule?.smoothingEnabled ?? true)))
    }

    func smoothsHorizontal(deviceRule: DeviceScrollRule? = nil, appRule: AppScrollRule? = nil) -> Bool {
        appRule?.bypassScrolling != true &&
            (appRule?.smoothingOverride ?? (settings.horizontalSmoothingEnabled && (deviceRule?.smoothingEnabled ?? true)))
    }

    func projectedSamples(from sample: ScrollSample, count: Int = 8) -> [ScrollSample] {
        guard settings.duration > 0, count > 0,
              (sample.x != 0 && smoothsHorizontal()) || (sample.y != 0 && smoothsVertical()) else {
            return [transform(sample)]
        }

        let transformed = transform(sample)
        var previousEase = 0.0
        return (0..<count).map { index in
            let progress = Double(index + 1) / Double(count)
            let easeOut = 1 - pow(1 - progress, 3)
            let weight = easeOut - previousEase
            previousEase = easeOut
            return ScrollSample(x: transformed.x * weight, y: transformed.y * weight)
        }
    }
}
