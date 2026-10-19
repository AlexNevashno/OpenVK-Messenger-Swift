import SwiftUI

public struct PhotoViewerItem: Identifiable, Equatable {
    public let id: String
    public let imageURL: URL?
    public let localImage: PlatformImage?
    public let caption: String
    public let authorName: String
    public let date: Date

    public init(
        id: String = UUID().uuidString,
        imageURL: URL? = nil,
        localImage: PlatformImage? = nil,
        caption: String = "",
        authorName: String = "",
        date: Date = Date()
    ) {
        self.id = id
        self.imageURL = imageURL
        self.localImage = localImage
        self.caption = caption
        self.authorName = authorName
        self.date = date
    }
}

@MainActor
public final class PhotoViewerService: ObservableObject {
    public static let shared = PhotoViewerService()

    @Published public var isOpen: Bool = false
    @Published public var items: [PhotoViewerItem] = []
    @Published public var currentIndex: Int = 0

    #if os(macOS)
    private var windowController: PhotoViewerWindowController?
    #endif

    public var currentItem: PhotoViewerItem? {
        guard currentIndex >= 0 && currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    private init() {}

    public func open(items: [PhotoViewerItem], initialIndex: Int = 0) {
        guard !items.isEmpty else { return }
        self.items = items
        self.currentIndex = max(0, min(initialIndex, items.count - 1))
        self.isOpen = true

        #if os(macOS)
        if windowController == nil {
            windowController = PhotoViewerWindowController()
        }
        windowController?.show(items: items, initialIndex: currentIndex)
        #endif
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
