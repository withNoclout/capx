import AppKit
import Foundation
import ImageIO

struct LoadedCapture {
    let url: URL
    let createdAt: Date
    let thumbnail: NSImage
}

final class ThumbnailLoader {
    private let queue = DispatchQueue(label: "com.withnoclout.capx.thumbnail-loader", qos: .userInitiated)

    func load(_ url: URL, completion: @escaping (LoadedCapture?) -> Void) {
        queue.async {
            let loaded = self.loadWithRetry(url)
            DispatchQueue.main.async {
                completion(loaded)
            }
        }
    }

    private func loadWithRetry(_ url: URL) -> LoadedCapture? {
        for attempt in 0..<8 {
            if let capture = autoreleasepool(invoking: { loadOnce(url) }) {
                return capture
            }

            if attempt < 7 {
                Thread.sleep(forTimeInterval: 0.10)
            }
        }

        return nil
    }

    private func loadOnce(_ url: URL) -> LoadedCapture? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 720,
            kCGImageSourceShouldCacheImmediately: false
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let createdAt = values?.creationDate ?? values?.contentModificationDate ?? Date()
        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )

        return LoadedCapture(url: url, createdAt: createdAt, thumbnail: image)
    }
}
