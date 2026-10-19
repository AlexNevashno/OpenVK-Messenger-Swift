import SwiftUI
import ImageIO
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Animated GIF View (Cross-Platform iOS & macOS)

public struct VKAnimatedGIFView: View {
    public let url: URL?
    public let localData: Data?
    public var allowsFullScreen: Bool = true
    public var onExpand: (() -> Void)? = nil

    @State private var gifData: Data? = nil
    @State private var isLoading = false
    @State private var loadFailed = false

    private static let dataMemoryCache = NSCache<NSURL, NSData>()

    public init(url: URL?, localData: Data? = nil, allowsFullScreen: Bool = true, onExpand: (() -> Void)? = nil) {
        self.url = url
        self.localData = localData
        self.allowsFullScreen = allowsFullScreen
        self.onExpand = onExpand

        if let local = localData {
            _gifData = State(initialValue: local)
        } else if let u = url, let cached = Self.dataMemoryCache.object(forKey: u as NSURL) {
            _gifData = State(initialValue: cached as Data)
        }
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = gifData ?? localData {
                PlatformGIFRepresentable(data: data, sourceURL: url)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onExpand?()
                    }

                // Telegram-style "GIF" badge pill
                HStack(spacing: 4) {
                    Text("GIF")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .padding(6)
            } else if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.08))
                    ProgressView()
                        .controlSize(.small)
                }
            } else if loadFailed {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.08))
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 18))
                            .foregroundColor(VKColors.textSecondary)
                        Text("GIF")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(VKColors.textSecondary)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.04))
            }
        }
        .task(id: url) {
            if gifData == nil && localData == nil {
                await loadGIFData()
            }
        }
    }

    private func loadGIFData() async {
        if let local = localData {
            self.gifData = local
            return
        }
        guard let url = url else { return }

        // 1. Check memory cache
        if let cached = Self.dataMemoryCache.object(forKey: url as NSURL) {
            self.gifData = cached as Data
            return
        }

        // 2. Check disk cache via URL hash in background
        let hash = String(format: "%016llx", abs(url.absoluteString.hashValue))
        let diskURL = VKImageCache.shared.cacheDir.appendingPathComponent("gif_\(hash).gif")
        
        let loadedFromDisk = await Task.detached(priority: .userInitiated) { () -> Data? in
            if FileManager.default.fileExists(atPath: diskURL.path),
               let diskData = try? Data(contentsOf: diskURL) {
                return diskData
            }
            return nil
        }.value

        if let diskData = loadedFromDisk {
            Self.dataMemoryCache.setObject(diskData as NSData, forKey: url as NSURL)
            self.gifData = diskData
            return
        }

        // 3. Download from network
        await MainActor.run { isLoading = true }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode ?? 200 < 400 else {
                await MainActor.run {
                    self.isLoading = false
                    self.loadFailed = true
                }
                return
            }

            Task.detached(priority: .background) {
                try? data.write(to: diskURL, options: .atomic)
            }
            Self.dataMemoryCache.setObject(data as NSData, forKey: url as NSURL)

            await MainActor.run {
                self.gifData = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.loadFailed = true
            }
        }
    }
}

// MARK: - Native GIF Platform Representable

#if os(macOS)
public struct PlatformGIFRepresentable: NSViewRepresentable {
    public let data: Data
    public let sourceURL: URL?

    public init(data: Data, sourceURL: URL? = nil) {
        self.data = data
        self.sourceURL = sourceURL
    }

    public func makeNSView(context: Context) -> NSImageView {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.animates = true
        iv.canDrawSubviewsIntoLayer = true
        iv.image = NSImage(data: data)
        return iv
    }

    public func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image == nil {
            nsView.image = NSImage(data: data)
        }
    }
}
#elseif os(iOS)
public struct PlatformGIFRepresentable: UIViewRepresentable {
    public let data: Data
    public let sourceURL: URL?

    private static let animatedImageCache = NSCache<NSString, UIImage>()

    public init(data: Data, sourceURL: URL? = nil) {
        self.data = data
        self.sourceURL = sourceURL
    }

    public func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        applyGIF(data: data, sourceURL: sourceURL, to: iv)
        return iv
    }

    public func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.image == nil {
            applyGIF(data: data, sourceURL: sourceURL, to: uiView)
        }
    }

    private func applyGIF(data: Data, sourceURL: URL?, to imageView: UIImageView) {
        let cacheKey = (sourceURL?.absoluteString ?? "\(data.count)_\(data.hashValue)") as NSString

        // Check if pre-decoded animated image is in memory
        if let cached = Self.animatedImageCache.object(forKey: cacheKey) {
            imageView.image = cached
            return
        }

        // Fast path: show first static frame immediately without waiting or freezing
        if let firstFrame = UIImage(data: data) {
            imageView.image = firstFrame
        }

        // Asynchronously decode animation frames in background thread to avoid any UI lag
        Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
            let count = CGImageSourceGetCount(source)
            guard count > 1 else { return }

            // Limit max frames to 60 to prevent memory exhaustion
            let step = max(1, count / 60)
            var frames: [UIImage] = []
            var totalDuration: TimeInterval = 0

            for i in stride(from: 0, to: count, by: step) {
                // Downsample large GIFs to 500px max dimension for smooth 60fps rendering
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 500,
                    kCGImageSourceShouldCacheImmediately: true
                ]
                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, i, options as CFDictionary) ?? CGImageSourceCreateImageAtIndex(source, i, nil) else {
                    continue
                }

                var frameDuration: TimeInterval = 0.1
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
                   let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                    if let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber, unclamped.doubleValue > 0.01 {
                        frameDuration = unclamped.doubleValue
                    } else if let delay = gifProperties[kCGImagePropertyGIFDelayTime] as? NSNumber, delay.doubleValue > 0.01 {
                        frameDuration = delay.doubleValue
                    }
                }
                if frameDuration < 0.02 {
                    frameDuration = 0.1
                }
                // Multiply by step if frames were skipped
                totalDuration += frameDuration * Double(step)
                frames.append(UIImage(cgImage: cgImage))
            }

            guard !frames.isEmpty else { return }
            let animatedImage = UIImage.animatedImage(with: frames, duration: max(0.1, totalDuration))

            if let img = animatedImage {
                Self.animatedImageCache.setObject(img, forKey: cacheKey)
                await MainActor.run {
                    imageView.image = img
                }
            }
        }
    }
}
#endif
