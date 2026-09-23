import AppKit

enum MacMenderBrandAssets {
    static let appIcon = "MacMenderAppIcon"

    private static let resourceBundle: Bundle? = {
        // SwiftPM's generated accessor looks beside the executable or in the
        // build directory. Packaged apps keep resources in Contents/Resources.
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let resources = Bundle.main.resourceURL else { return nil }
            return Bundle(url: resources.appendingPathComponent("macMender_macMender.bundle"))
        }
        return Bundle.module
    }()

    static var applicationIconImage: NSImage {
        image(named: appIcon) ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    static var statusItemImage: NSImage {
        MacMenderStatusIcon.makeImage()
    }

    static func image(named name: String) -> NSImage? {
        if let image = NSImage(named: name) {
            return image
        }

        for bundle in [resourceBundle, Bundle.main].compactMap({ $0 }) {
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
