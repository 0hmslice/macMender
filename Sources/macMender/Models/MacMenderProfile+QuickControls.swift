import Foundation

extension MacMenderProfile {
    var isThreeFingerTapEnabled: Bool {
        middleClick.enabled && middleClick.trigger == .experimentalThreeFinger
    }

    mutating func setThreeFingerTapEnabled(_ isEnabled: Bool) {
        middleClick.enabled = isEnabled
        if isEnabled, middleClick.trigger == .disabled {
            middleClick.trigger = .experimentalThreeFinger
        }
    }

    var isExternalMouseReverseScrollingEnabled: Bool {
        scroll.deviceRules.first(where: { $0.deviceKind == .externalMouse })?.reverseVertical
            ?? scroll.reverseVertical
    }

    mutating func setExternalMouseReverseScrollingEnabled(_ isEnabled: Bool) {
        if let index = scroll.deviceRules.firstIndex(where: { $0.deviceKind == .externalMouse }) {
            scroll.deviceRules[index].reverseVertical = isEnabled
        } else {
            scroll.deviceRules.append(
                DeviceScrollRule(
                    id: UUID(),
                    deviceKind: .externalMouse,
                    displayName: "External Mouse",
                    reverseVertical: isEnabled,
                    reverseHorizontal: false,
                    smoothingEnabled: scroll.verticalSmoothingEnabled,
                    isPhysicalDeviceSpecific: false
                )
            )
        }
    }
}
