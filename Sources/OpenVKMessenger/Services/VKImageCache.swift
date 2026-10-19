import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import CryptoKit
import Lottie

// MARK: - Persistent In-Memory & Disk Image Cache
@MainActor
public final class VKImageCache {
    public static let shared = VKImageCache()

    private let memoryCache = NSCache<NSURL, PlatformImage>()
    private let fileManager = FileManager.default
    nonisolated private let diskCacheURL: URL
    nonisolated public var cacheDir: URL { diskCacheURL }
    private var inFlightTasks: [URL: Task<PlatformImage?, Never>] = [:]

    private init() {
        memoryCache.countLimit = 800
        memoryCache.totalCostLimit = 200 * 1024 * 1024 // 200 MB in-memory limit

        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheBase = paths.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        diskCacheURL = cacheBase.appendingPathComponent("OpenVKImageCache", isDirectory: true)

        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    private func diskFilePath(for url: URL) -> URL {
        let key = url.absoluteString
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        return diskCacheURL.appendingPathComponent("\(hash).\(ext)")
    }

    /// Fast synchronous memory & disk check (returns immediately for instant rendering without layout shift)
    public func image(for url: URL) -> PlatformImage? {
        if let mem = memoryCache.object(forKey: url as NSURL) {
            return mem
        }

        let file = diskFilePath(for: url)
        if let data = try? Data(contentsOf: file), let diskImg = PlatformImage.from(data: data) {
            memoryCache.setObject(diskImg, forKey: url as NSURL, cost: data.count)
            return diskImg
        }

        return nil
    }

    public func insert(_ image: PlatformImage, data: Data?, for url: URL) {
        memoryCache.setObject(image, forKey: url as NSURL, cost: data?.count ?? 512 * 1024)
        if let d = data {
            let file = diskFilePath(for: url)
            Task.detached(priority: .background) {
                try? d.write(to: file, options: .atomic)
            }
        }
    }

    public func loadImage(for url: URL) async -> PlatformImage? {
        // 1. Check synchronous cache
        if let existing = image(for: url) {
            return existing
        }

        // 2. Deduplicate in-flight downloads for the same URL
        if let ongoing = inFlightTasks[url] {
            return await ongoing.value
        }

        let task = Task<PlatformImage?, Never> { [weak self] () -> PlatformImage? in
            guard let self = self else { return nil }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    return nil
                }
                if let img = PlatformImage.from(data: data) {
                    await MainActor.run {
                        self.insert(img, data: data, for: url)
                    }
                    return img
                }
            } catch {
                // Silently handle cancelled or network errors
            }
            return nil
        }

        inFlightTasks[url] = task
        let result = await task.value
        inFlightTasks[url] = nil
        return result
    }

    public func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}

// MARK: - VKCachedAsyncImage View
/// High-performance cached image view that loads instantly from memory/disk cache,
/// avoiding layout jumps and continuous network re-downloads in LazyVStack.
public struct VKCachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var loadedImage: PlatformImage?

    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        if let u = url, let cached = VKImageCache.shared.image(for: u) {
            _loadedImage = State(initialValue: cached)
        }
    }

    public var body: some View {
        Group {
            if let img = loadedImage {
                content(Image(platformImage: img))
            } else {
                placeholder()
                    .task(id: url) {
                        guard let u = url else { return }
                        if loadedImage == nil {
                            if let found = await VKImageCache.shared.loadImage(for: u) {
                                self.loadedImage = found
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Persistent Sticker & Animation Cache
public final class VKStickerCache: @unchecked Sendable {
    public static let shared = VKStickerCache()

    private let fileManager = FileManager.default
    private let cacheDirectoryURL: URL
    private let animationsDirectoryURL: URL
    private let packsCacheFileURL: URL

    private let memoryAnimationCache = NSCache<NSURL, LottieAnimation>()
    private var inFlightAnimationTasks: [URL: Task<LottieAnimation?, Never>] = [:]
    private let lock = NSLock()

    private init() {
        memoryAnimationCache.countLimit = 200

        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheBase = paths.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let root = cacheBase.appendingPathComponent("OpenVKStickers", isDirectory: true)
        self.cacheDirectoryURL = root
        self.animationsDirectoryURL = root.appendingPathComponent("animations", isDirectory: true)
        self.packsCacheFileURL = root.appendingPathComponent("packs_cache.json")

        try? fileManager.createDirectory(at: animationsDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Sticker Packs Metadata Cache

    public func cachedStickerPacks() -> [VKStickerPack]? {
        guard fileManager.fileExists(atPath: packsCacheFileURL.path),
              let data = try? Data(contentsOf: packsCacheFileURL) else {
            return nil
        }
        return try? JSONDecoder().decode([VKStickerPack].self, from: data)
    }

    public func saveStickerPacks(_ packs: [VKStickerPack]) {
        DispatchQueue.global(qos: .utility).async { [packsCacheFileURL] in
            guard let data = try? JSONEncoder().encode(packs) else { return }
            try? data.write(to: packsCacheFileURL, options: .atomic)
        }
    }

    // MARK: - Animation Disk & Memory Cache

    private func animationFilePath(for url: URL) -> URL {
        let key = url.absoluteString
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return animationsDirectoryURL.appendingPathComponent("\(hash).json")
    }

    public func cachedAnimation(from url: URL) -> LottieAnimation? {
        if let cached = memoryAnimationCache.object(forKey: url as NSURL) {
            return cached
        }
        let filePath = animationFilePath(for: url)
        if fileManager.fileExists(atPath: filePath.path),
           let data = try? Data(contentsOf: filePath) {
            if let animation = try? LottieAnimation.from(data: data) {
                memoryAnimationCache.setObject(animation, forKey: url as NSURL)
                return animation
            }
        }
        return nil
    }

    public func loadAnimation(from url: URL) async -> LottieAnimation? {
        // 1. In-memory cache
        if let cached = cachedAnimation(from: url) {
            return cached
        }

        // 2. Disk cache check
        let filePath = animationFilePath(for: url)
        if fileManager.fileExists(atPath: filePath.path),
           let data = try? Data(contentsOf: filePath) {
            if let animation = try? LottieAnimation.from(data: data) {
                memoryAnimationCache.setObject(animation, forKey: url as NSURL)
                return animation
            }
        }

        // 3. In-flight task deduplication
        lock.lock()
        if let ongoing = inFlightAnimationTasks[url] {
            lock.unlock()
            return await ongoing.value
        }

        let task = Task<LottieAnimation?, Never> { [weak self] () -> LottieAnimation? in
            guard let self = self else { return nil }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    return nil
                }

                // Write to disk cache atomically
                try? data.write(to: filePath, options: .atomic)

                // Decode animation
                if let anim = try? LottieAnimation.from(data: data) {
                    self.memoryAnimationCache.setObject(anim, forKey: url as NSURL)
                    return anim
                }
            } catch {
                // Network error or task cancelled
            }
            return nil
        }

        inFlightAnimationTasks[url] = task
        lock.unlock()

        let result = await task.value

        lock.lock()
        inFlightAnimationTasks[url] = nil
        lock.unlock()

        return result
    }

    public func clearCache() {
        memoryAnimationCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectoryURL)
        try? fileManager.createDirectory(at: animationsDirectoryURL, withIntermediateDirectories: true)
    }
}

// MARK: - Telegram-Style Persistent Disk & Memory Chat Cache
public final class VKChatCache {
    public static let shared = VKChatCache()

    private let fileManager = FileManager.default
    private let cacheBaseURL: URL
    private let ioQueue = DispatchQueue(label: "com.alexs.openvk.chatcache.io", qos: .utility)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // In-memory hot caches for instant multi-read
    private let memoryLock = NSLock()
    private var memConversations: [String: [VKConversation]] = [:]
    private var memMessages: [String: [VKMessage]] = [:] // Key: "\(accountKey)_\(peerId)"

    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let base = paths.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        cacheBaseURL = base.appendingPathComponent("OpenVKChatDataCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheBaseURL, withIntermediateDirectories: true)
    }

    private func accountDirectoryURL(for accountKey: String) -> URL {
        let hash = SHA256.hash(data: Data(accountKey.utf8)).map { String(format: "%02x", $0) }.joined()
        let dir = cacheBaseURL.appendingPathComponent(hash, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Conversations Cache

    public func loadConversations(for accountKey: String) -> [VKConversation]? {
        memoryLock.lock()
        if let memory = memConversations[accountKey], !memory.isEmpty {
            memoryLock.unlock()
            return memory
        }
        memoryLock.unlock()

        let file = accountDirectoryURL(for: accountKey).appendingPathComponent("conversations.json")
        guard fileManager.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let decoded = try? decoder.decode([VKConversation].self, from: data) else {
            return nil
        }

        memoryLock.lock()
        memConversations[accountKey] = decoded
        memoryLock.unlock()

        return decoded
    }

    public func saveConversations(_ conversations: [VKConversation], for accountKey: String) {
        let toSave = Array(conversations.prefix(100))
        memoryLock.lock()
        memConversations[accountKey] = toSave
        memoryLock.unlock()

        let file = accountDirectoryURL(for: accountKey).appendingPathComponent("conversations.json")
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            if let data = try? self.encoder.encode(toSave) {
                try? data.write(to: file, options: .atomic)
            }
        }
    }

    // MARK: - Messages Cache

    public func loadMessages(for peerId: Int, accountKey: String) -> [VKMessage]? {
        let key = "\(accountKey)_\(peerId)"
        memoryLock.lock()
        if let memory = memMessages[key], !memory.isEmpty {
            memoryLock.unlock()
            return memory
        }
        memoryLock.unlock()

        let file = accountDirectoryURL(for: accountKey).appendingPathComponent("messages_\(peerId).json")
        guard fileManager.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let decoded = try? decoder.decode([VKMessage].self, from: data) else {
            return nil
        }

        memoryLock.lock()
        memMessages[key] = decoded
        memoryLock.unlock()

        return decoded
    }

    public func saveMessages(_ messages: [VKMessage], for peerId: Int, accountKey: String) {
        // Save only valid messages with real positive IDs, keep last 150 items
        let realMessages = messages.filter { $0.id > 0 }
        let toSave = Array(realMessages.suffix(150))
        let key = "\(accountKey)_\(peerId)"

        memoryLock.lock()
        memMessages[key] = toSave
        memoryLock.unlock()

        let file = accountDirectoryURL(for: accountKey).appendingPathComponent("messages_\(peerId).json")
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            if let data = try? self.encoder.encode(toSave) {
                try? data.write(to: file, options: .atomic)
            }
        }
    }

    public func clearCache(for accountKey: String) {
        memoryLock.lock()
        memConversations.removeValue(forKey: accountKey)
        let prefix = "\(accountKey)_"
        memMessages = memMessages.filter { !$0.key.hasPrefix(prefix) }
        memoryLock.unlock()

        let dir = accountDirectoryURL(for: accountKey)
        try? fileManager.removeItem(at: dir)
    }
}

