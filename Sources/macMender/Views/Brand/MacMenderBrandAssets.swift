import AppKit

enum MacMenderBrandAssets {
    static let appIcon = "MacMenderAppIcon"

    static var applicationIconImage: NSImage {
        image(named: appIcon) ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    static var statusItemImage: NSImage {
        let image = NSImage(
            systemSymbolName: "laptopcomputer",
            accessibilityDescription: "macMender"
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        ) ?? applicationIconImage
        image.isTemplate = true
        return image
    }

    static func image(named name: String) -> NSImage? {
        if let image = NSImage(named: name) {
            return image
        }

        for bundle in [Bundle.module, Bundle.main] {
            for subdirectory in ["Brand", nil] {
                if let url = bundle.url(
                    forResource: name,
                    withExtension: "png",
                    subdirectory: subdirectory
                ), let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        return nil
    }
}
