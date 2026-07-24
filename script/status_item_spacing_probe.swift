#!/usr/bin/env swift

import AppKit
import Foundation

private let app = NSApplication.shared
app.setActivationPolicy(.accessory)

private func makeProbeItem(label: String, symbolName: String) -> NSStatusItem {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    guard let button = item.button else { return item }

    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
    image?.isTemplate = true
    image?.size = NSSize(width: 16, height: 16)
    button.image = image
    button.imagePosition = .imageOnly
    button.setAccessibilityLabel(label)
    return item
}

private func format(_ frame: CGRect?) -> String {
    guard let frame else { return "unavailable" }
    return String(
        format: "x=%.1f y=%.1f w=%.1f h=%.1f",
        frame.origin.x,
        frame.origin.y,
        frame.size.width,
        frame.size.height
    )
}

let firstItem = makeProbeItem(label: "macMender spacing probe A", symbolName: "circle.fill")
let secondItem = makeProbeItem(label: "macMender spacing probe B", symbolName: "square.fill")

DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
    let firstFrame = firstItem.button?.window?.frame
    let secondFrame = secondItem.button?.window?.frame
    let sortedFrames = [firstFrame, secondFrame].compactMap { $0 }.sorted { $0.minX < $1.minX }
    let hostFrameSeparation: CGFloat? = sortedFrames.count == 2 ? sortedFrames[1].minX - sortedFrames[0].maxX : nil

    print("probeA=[\(format(firstFrame))]")
    print("probeB=[\(format(secondFrame))]")
    print("hostFrameSeparation=\(hostFrameSeparation.map { String(format: "%.1f", $0) } ?? "unavailable")")

    NSStatusBar.system.removeStatusItem(firstItem)
    NSStatusBar.system.removeStatusItem(secondItem)
    app.terminate(nil)
}

app.run()
