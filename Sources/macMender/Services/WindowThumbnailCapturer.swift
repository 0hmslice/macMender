import CoreGraphics
import Foundation

struct WindowThumbnailRequest: Sendable {
    var id: WindowSummary.ID
    var windowID: CGWindowID
    /// Largest useful size in pixels; captures are scaled down to fit.
    var maxPixelSize: CGSize
}

/// Captures window contents straight from the window server, off the main thread.
/// Unlike on-screen capture this works for covered, minimized, and other-Space windows.
enum WindowThumbnailCapturer {
    static var isAvailable: Bool {
        PrivateWindowAPI.canCaptureWindows && CGPreflightScreenCaptureAccess()
    }

    static func capture(_ requests: [WindowThumbnailRequest]) async -> [WindowSummary.ID: CGImage] {
        guard isAvailable, !requests.isEmpty else { return [:] }
        return await withTaskGroup(of: (WindowSummary.ID, CGImage?).self) { group in
            for request in requests {
                group.addTask(priority: .userInitiated) {
                    guard !Task.isCancelled, let image = PrivateWindowAPI.captureWindow(request.windowID) else {
                        return (request.id, nil)
                    }
                    return (request.id, downscale(image, toFit: request.maxPixelSize))
                }
            }

            var images = [WindowSummary.ID: CGImage]()
            for await (id, image) in group {
                if let image {
                    images[id] = image
                }
            }
            return images
        }
    }

    static func downscale(_ image: CGImage, toFit maxPixelSize: CGSize) -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > 0, height > 0, maxPixelSize.width > 0, maxPixelSize.height > 0 else { return image }
        let scale = min(maxPixelSize.width / width, maxPixelSize.height / height)
        guard scale < 0.9 else { return image }

        let targetWidth = max(1, Int((width * scale).rounded()))
        let targetHeight = max(1, Int((height * scale).rounded()))
        let colorSpace = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return image
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage() ?? image
    }
}
