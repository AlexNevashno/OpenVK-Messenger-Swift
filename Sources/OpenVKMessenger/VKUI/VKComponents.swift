import SwiftUI

// MARK: - Avatar with Online Status Indicator
public struct VKAvatarView: View {
    public let url: URL?
    public let name: String
    public let size: CGFloat
    public let isOnline: Bool
    public let isMobile: Bool

    public let isSavedMessages: Bool
    @ObservedObject private var theme = ThemeManager.shared

    public init(
        url: URL? = nil,
        name: String = "",
        size: CGFloat = 46,
        isOnline: Bool = false,
        isMobile: Bool = false,
        isSavedMessages: Bool = false
    ) {
        self.url = url
        self.name = name
        self.size = size
        self.isOnline = isOnline
        self.isMobile = isMobile
        self.isSavedMessages = isSavedMessages
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2, let first = parts[0].first, let second = parts[1].first {
            return "\(first)\(second)".uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    private var fallbackColor: Color {
        let colors: [Color] = [
            Color(red: 0.28, green: 0.52, blue: 0.8),
            Color(red: 0.89, green: 0.38, blue: 0.42),
            Color(red: 0.35, green: 0.65, blue: 0.45),
            Color(red: 0.95, green: 0.60, blue: 0.25),
            Color(red: 0.58, green: 0.42, blue: 0.78)
        ]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    public var body: some View {
        Group {
            if isSavedMessages {
                ZStack {
                    Circle()
                        .fill(VKColors.accent)
                        .frame(width: size, height: size)
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: size * 0.44))
                        .foregroundColor(.white)
                }
            } else {
                ZStack(alignment: .bottomTrailing) {
                    if let url = url {
                        VKCachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            fallbackView
                        }
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                    } else {
                        fallbackView
                    }

                    // Online Badge
                    if isOnline {
                        ZStack {
                            Circle()
                                .fill(VKColors.surface)
                                .frame(width: size * 0.28 + 4, height: size * 0.28 + 4)

                            if isMobile {
                                ZStack {
                                    Circle()
                                        .fill(VKColors.onlineGreen)
                                        .frame(width: size * 0.28, height: size * 0.28)
                                    Image(systemName: "iphone")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: size * 0.16, height: size * 0.16)
                                        .foregroundColor(.white)
                                }
                            } else {
                                Circle()
                                    .fill(VKColors.onlineGreen)
                                    .frame(width: size * 0.26, height: size * 0.26)
                            }
                        }
                        .offset(x: 1, y: 1)
                    }
                }
            }
        }
    }

    private var fallbackView: some View {
        Circle()
            .fill(fallbackColor)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Verified Checkmark Badge
public struct VKVerifiedBadge: View {
    @ObservedObject private var theme = ThemeManager.shared
    public init() {}
    public var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 13))
            .foregroundColor(VKColors.verified)
    }
}

// MARK: - Unread Badge Pill
public struct VKUnreadBadge: View {
    public let count: Int
    @ObservedObject private var theme = ThemeManager.shared

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(VKTypography.badge)
                .foregroundColor(VKColors.textOnAccent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(VKColors.accent)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Milkshake Search Field
public struct VKSearchField: View {
    @Binding public var text: String
    public var placeholder: String = "Поиск"
    @ObservedObject private var theme = ThemeManager.shared

    public init(text: Binding<String>, placeholder: String = "Поиск") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(VKColors.textSecondary)
                .font(.system(size: 13, weight: .medium))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(VKTypography.subhead)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(VKColors.textSecondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(VKColors.secondarySurface)
        .cornerRadius(8)
    }
}

// MARK: - Wall Post Card (Repost Attachment)
public struct VKWallPostCard: View {
    public let authorName: String
    public let authorAvatarURL: URL?
    public let dateString: String
    public let text: String
    public let imageURL: URL?
    public let photos: [VKPhotoAttachment]
    public let audios: [VKAudioAttachment]
    public let videos: [VKVideoAttachment]
    public let docs: [VKDocAttachment]
    public let isOutgoing: Bool

    public init(
        authorName: String,
        authorAvatarURL: URL? = nil,
        dateString: String,
        text: String,
        imageURL: URL? = nil,
        photos: [VKPhotoAttachment] = [],
        audios: [VKAudioAttachment] = [],
        videos: [VKVideoAttachment] = [],
        docs: [VKDocAttachment] = [],
        isOutgoing: Bool = false
    ) {
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
        self.dateString = dateString
        self.text = text
        self.imageURL = imageURL ?? photos.first?.url
        if photos.isEmpty, let u = imageURL {
            self.photos = [VKPhotoAttachment(id: 0, url: u)]
        } else {
            self.photos = photos
        }
        self.audios = audios
        self.videos = videos
        self.docs = docs
        self.isOutgoing = isOutgoing
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left Quote Bar (Milkshake style)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(ThemeManager.shared.replyAuthorNameColor(isOutgoingBubble: isOutgoing))
                .frame(width: 2.5)

            VStack(alignment: .leading, spacing: 8) {
                // Author Header
                HStack(spacing: 8) {
                    if let authorAvatarURL = authorAvatarURL {
                        AsyncImage(url: authorAvatarURL) { phase in
                            switch phase {
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        VKAvatarView(url: nil, name: authorName, size: 32)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authorName)
                            .font(VKTypography.headline)
                            .foregroundColor(ThemeManager.shared.replyAuthorNameColor(isOutgoingBubble: isOutgoing))
                        Text(dateString)
                            .font(VKTypography.caption)
                            .foregroundColor(ThemeManager.shared.replyDateColor(isOutgoingBubble: isOutgoing))
                    }
                }

                // Post Text
                if !text.isEmpty {
                    Text(text)
                        .font(VKTypography.body)
                        .foregroundColor(ThemeManager.shared.replyTextColor(isOutgoingBubble: isOutgoing))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Attached Photos
                if photos.count == 1, let single = photos.first {
                    Button(action: { openPhotoInViewer(index: 0) }) {
                        AsyncImage(url: single.url) { phase in
                            switch phase {
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(8)
                                    .frame(maxHeight: 300)
                            case .failure:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(VKColors.secondarySurface)
                                    .frame(height: 140)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(VKColors.textSecondary)
                                    )
                            case .empty:
                                ProgressView()
                                    .frame(height: 100)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else if photos.count > 1 {
                    // Telegram/VK style horizontal row of photos
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(photos.enumerated()), id: \.offset) { index, p in
                                Button(action: { openPhotoInViewer(index: index) }) {
                                    AsyncImage(url: p.url) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 86, height: 160)
                                                .clipped()
                                                .cornerRadius(6)
                                        case .failure:
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(VKColors.secondarySurface)
                                                .frame(width: 86, height: 160)
                                                .overlay(Image(systemName: "photo").foregroundColor(VKColors.textSecondary))
                                        case .empty:
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.gray.opacity(0.15))
                                                .frame(width: 86, height: 160)
                                                .overlay(ProgressView().scaleEffect(0.8))
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Attached Audios
                if !audios.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(audios) { audio in
                            HStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 13))
                                    .foregroundColor(VKColors.accent)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(audio.title)
                                        .font(VKTypography.subhead)
                                        .foregroundColor(ThemeManager.shared.replyTextColor(isOutgoingBubble: isOutgoing))
                                        .lineLimit(1)
                                    Text(audio.artist)
                                        .font(VKTypography.caption)
                                        .foregroundColor(VKColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Attached Documents
                if !docs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(docs) { doc in
                            HStack(spacing: 8) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(VKColors.accent)
                                Text(doc.title)
                                    .font(VKTypography.subhead)
                                    .foregroundColor(ThemeManager.shared.replyTextColor(isOutgoingBubble: isOutgoing))
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Attached Videos
                if !videos.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(videos) { vid in
                            HStack(spacing: 8) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(VKColors.accent)
                                Text(vid.title)
                                    .font(VKTypography.subhead)
                                    .foregroundColor(ThemeManager.shared.replyTextColor(isOutgoingBubble: isOutgoing))
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func openPhotoInViewer(index: Int) {
        let allItems = photos.enumerated().map { (idx, p) in
            PhotoViewerItem(
                id: "\(idx)_\(p.id)",
                imageURL: p.url,
                caption: p.text.isEmpty ? text : p.text,
                authorName: authorName,
                date: Date()
            )
        }
        guard !allItems.isEmpty else { return }
        let targetIdx = min(max(0, index), allItems.count - 1)
        PhotoViewerService.shared.open(items: allItems, initialIndex: targetIdx)
    }
}

// MARK: - Animated Typing Dots Indicator
public struct TypingDotsIndicator: View {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var animating = false

    public init() {}

    public var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(VKColors.accent)
                .frame(width: 4, height: 4)
                .scaleEffect(animating ? 1.3 : 0.7)
                .opacity(animating ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.5).repeatForever().delay(0.0), value: animating)

            Circle()
                .fill(VKColors.accent)
                .frame(width: 4, height: 4)
                .scaleEffect(animating ? 1.3 : 0.7)
                .opacity(animating ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.5).repeatForever().delay(0.18), value: animating)

            Circle()
                .fill(VKColors.accent)
                .frame(width: 4, height: 4)
                .scaleEffect(animating ? 1.3 : 0.7)
                .opacity(animating ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.5).repeatForever().delay(0.36), value: animating)
        }
        .onAppear {
            animating = true
        }
    }
}

