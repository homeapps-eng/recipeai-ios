import SwiftUI
import UIKit
import ImageIO

// MARK: - Downsampling

/// Decodes images at the size they are needed instead of at full resolution.
nonisolated enum ImageDownsampler {
    /// Decodes `data` with its longest side at most `maxPixelSize`, with the
    /// EXIF orientation applied.
    static func image(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = makeSource(data) else { return nil }
        return thumbnail(from: source, maxPixelSize: maxPixelSize)
    }

    /// Decodes `data` just large enough to aspect-fill `pixelSize`.
    static func image(from data: Data, toFill pixelSize: CGSize) -> UIImage? {
        guard let source = makeSource(data),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else {
            return nil
        }
        let scale = min(1, max(pixelSize.width / width, pixelSize.height / height))
        return thumbnail(from: source, maxPixelSize: max(width, height) * scale)
    }

    private static func makeSource(_ data: Data) -> CGImageSource? {
        // Don't let ImageIO keep the full-size decode around; only the thumbnail is used.
        CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
    }

    private static func thumbnail(from source: CGImageSource, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize.rounded(.up))
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Loader

/// Loads remote images with a disk cache and decodes them at display size.
actor ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let decoded = NSCache<NSString, UIImage>()

    private init() {
        // Dish images never change once written (the bucket serves them with a
        // one-year max-age), so keep the downloads on disk across launches.
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("recipe-images")
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 200 * 1024 * 1024, directory: directory)
        session = URLSession(configuration: config)

        decoded.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL, toFill pixelSize: CGSize) async throws -> UIImage {
        let key = "\(url.absoluteString)|\(Int(pixelSize.width))x\(Int(pixelSize.height))" as NSString
        if let cached = decoded.object(forKey: key) {
            return cached
        }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let image = ImageDownsampler.image(from: data, toFill: pixelSize) else {
            throw URLError(.cannotDecodeContentData)
        }

        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        decoded.setObject(image, forKey: key, cost: cost)
        return image
    }
}

// MARK: - View

/// `AsyncImage` replacement backed by `ImageLoader`: downloads are cached on
/// disk and decoded at the size of the view rather than at full resolution.
/// Fills the frame it is given.
struct RemoteImage<Content: View>: View {
    let url: URL
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @Environment(\.displayScale) private var displayScale
    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        GeometryReader { proxy in
            content(phase)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .task(id: ImageRequest(url: url, size: proxy.size)) {
                    await load(toFill: proxy.size)
                }
        }
    }

    private func load(toFill size: CGSize) async {
        guard size.width > 0, size.height > 0 else { return }
        phase = .empty

        let pixelSize = CGSize(width: size.width * displayScale, height: size.height * displayScale)
        do {
            let image = try await ImageLoader.shared.image(for: url, toFill: pixelSize)
            phase = .success(Image(uiImage: image))
        } catch {
            if !Task.isCancelled {
                phase = .failure(error)
            }
        }
    }
}

private struct ImageRequest: Equatable {
    let url: URL
    let size: CGSize
}
