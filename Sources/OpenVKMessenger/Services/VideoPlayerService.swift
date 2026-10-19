import SwiftUI

public struct VideoPlayerItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let videoURL: URL?
    public let playerWebURL: URL?
    public let thumbnailURL: URL?
    public let duration: Int
    public let ownerId: Int?
    public let videoId: Int?
    public let accessKey: String?

    public init(
        id: String = UUID().uuidString,
        title: String = "Видеозапись",
        subtitle: String = "",
        videoURL: URL? = nil,
        playerWebURL: URL? = nil,
        thumbnailURL: URL? = nil,
        duration: Int = 0,
        ownerId: Int? = nil,
        videoId: Int? = nil,
        accessKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.videoURL = videoURL
        self.playerWebURL = playerWebURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.ownerId = ownerId
        self.videoId = videoId
        self.accessKey = accessKey
    }
}

@MainActor
public final class VideoPlayerService: ObservableObject {
    public static let shared = VideoPlayerService()

    @Published public var isOpen: Bool = false
    @Published public var items: [VideoPlayerItem] = []
    @Published public var currentIndex: Int = 0

    #if os(macOS)
    private var windowController: VideoPlayerWindowController?
    #endif

    public var currentItem: VideoPlayerItem? {
        guard currentIndex >= 0 && currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    private init() {}

    public func open(items: [VideoPlayerItem], initialIndex: Int = 0) {
        guard !items.isEmpty else { return }
        self.items = items
        self.currentIndex = max(0, min(initialIndex, items.count - 1))
        self.isOpen = true

        #if os(macOS)
        if windowController == nil {
            windowController = VideoPlayerWindowController()
        }
        windowController?.show(items: items, initialIndex: currentIndex)
        #endif
    }

    public func open(item: VideoPlayerItem) {
        open(items: [item], initialIndex: 0)
    }

    public func close() {
        self.isOpen = false
        #if os(macOS)
        windowController?.close()
        #endif
    }

    public func next() {
        if currentIndex < items.count - 1 {
            withAnimation(.easeInOut(duration: 0.22)) {
                currentIndex += 1
            }
        }
    }

    public func previous() {
        if currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.22)) {
                currentIndex -= 1
            }
        }
    }
}
